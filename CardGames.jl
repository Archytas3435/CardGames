### A Pluto.jl notebook ###
# v0.17.2

using Markdown
using InteractiveUtils

# ╔═╡ f206a273-a11f-41e5-a9b0-57f4851df198
using ReinforcementLearning

# ╔═╡ 8a66a07b-6de0-441c-98cb-4863d3f08c01
begin
	using Flux
	using Flux.Losses
end

# ╔═╡ 3212caa0-9354-44ac-a5d3-c71e11cf790d
using Random

# ╔═╡ 0d906b45-1c08-4b91-91b9-7353a3e81f2e
using Intervals

# ╔═╡ f1741ee5-dbf9-4ec5-9bc0-fc4887e83ddc
using StableRNGs

# ╔═╡ c664b43d-f3b6-4b23-b74e-fe40f7440d85
using Plots

# ╔═╡ 25db9bdc-14cd-479e-bb18-573596c8efc6
md"# Importing Packages"

# ╔═╡ 60682e2f-b255-4475-94b2-f62f61de151a
md"# Defining Some Methods and Constants"

# ╔═╡ 7de6ccf6-6083-4e7a-952d-b57117c70a29
begin
	duplicate(arr::Array) = vcat(arr, arr)
	duplicate(arrs...) = duplicate(vcat(arrs...))
end

# ╔═╡ ef4c81e1-93db-4a18-ac7c-bb02f2e487af
moving_average(arr::Array, n::Int) = [sum(arr[i:i+n])/n for i in 1:length(arr)-n]

# ╔═╡ da5c5e6c-f262-47fa-a064-d5461053685d
begin
	const N_STEPS = 100000
	const NAMES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	const VALUES_1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
	const VALUES_2 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]
	const VALUES_3 = [14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
	const SUITS = ["diamonds", "clubs", "hearts", "spades"]
	const SUITS_TO_COLORS = Dict(
		"diamonds"=>"red", 
		"clubs"=>"black", 
		"hearts"=>"red", 
		"spades"=>"black"
	)
	const UNO_COLORS = ["blue", "green", "red", "yellow"]
	const UNO_VALUES = vcat([0], duplicate(Array(1:9)))
	const UNO_SPECIALS = duplicate(["+2", "reverse", "skip"])
	const UNO_WILDS = duplicate(duplicate(["wild", "wild+4"]))
	md"`consts` initialized"
end

# ╔═╡ 65396323-2f82-48dc-af49-7fa6e2467d87
md"# Defining Structs"

# ╔═╡ 5a626901-e68c-466c-8dc5-b3a677a79d2a
mutable struct Card
	name::String
	value::Union{Int64,Nothing}
	suit::Union{String,Nothing}
	special::Union{String,Nothing}
	Card(name::String, suit::String, special::String) = new(
		name,
		nothing,
		suit,
		special
	)
	Card(name::String, value::Int64, suit::String) = new(
		name,
		value,
		suit,
		nothing
	)
	Card(name::String, value::Int64, suit::Union{Nothing,String}) = new(
		name,
		value,
		suit,
		nothing
	)
	Card(name::String, value::Int64, suit::Union{Nothing,String}, special::String) = new(
		name,
		value,
		suit,
		special
	)
end

# ╔═╡ 1ac26e69-4730-4814-b9ff-588131e56c09
const DeckTypes = Dict(
	:StandardNoJokers => [
		Card(NAMES[i], VALUES_1[i], SUITS[j])
		for i in 1:13
		for j in 1:4
	],
	:StandardWithJokers => vcat(
		[
			Card(NAMES[i], VALUES_1[i], SUITS[j])
			for i in 1:13
			for j in 1:4
		],
		[
			Card("Joker", 0, nothing, "wild"),
			Card("Joker", 0, nothing, "wild")
		]
	),
	:StandardNoJokersFace10 => [
		Card(NAMES[i], VALUES_2[i], SUITS[j])
		for i in 1:13
		for j in 1:4
	],
	:StandardNoJokersAceHighest => [
		Card(NAMES[i], VALUES_3[i], SUITS[j])
		for i in 1:13
		for j in 1:4
	],
	:DoubleStandardNoJokers => duplicate(
		[
			Card(NAMES[i], VALUES_1[i], SUITS[j])
			for i in 1:13
			for j in 1:4
		]
	),
	:DoubleStandardWithJokers => duplicate(
		[
			Card(NAMES[i], VALUES_1[i], SUITS[j])
			for i in 1:13
			for j in 1:4
		],
		[
			Card("Joker", 0, nothing, "wild"),
			Card("Joker", 0, nothing, "wild")
		]
	),
	:StandardUno => vcat(
		[
			Card(string(UNO_VALUES[i]), UNO_VALUES[i], UNO_COLORS[j])
			for i in 1:19
			for j in 1:4
		],
		[
			Card(UNO_SPECIALS[i], UNO_COLORS[j], UNO_SPECIALS[i])
			for i in 1:6
			for j in 1:4
		],
		[
			Card(UNO_WILDS[i], "black", UNO_WILDS[i])
			for i in 1:8
		]
	)
)

# ╔═╡ fa7eb71d-9bf8-497c-b68e-df16dc6b4165
mutable struct Deck
	cards::Array{Card,1}
	played_cards::Array{Card,1}
	drawpile::Array{Card,1}
	Deck(cards::Array{Card,1}) = new(
		cards,
		Card[],
		copy(cards)
	)
end

# ╔═╡ e16cf8ad-e9d3-411a-b4ea-3d2db916c20f
md"# Defining Specific Methods"

# ╔═╡ d03a3b60-5272-4b65-a78b-1bbabec89545
broadcastDict(dict::Dict, arr::Array) = map(x->dict[x], arr)

# ╔═╡ 6b5cbcac-9a0d-44d5-a808-7dec85f57a9f
begin
	valuesOnly(arr::Array{Card,1}) = (x->x.value).(arr)
	valuesOnly(d::Deck) = [count(x->x.value==i, d.cards) for i in minimum((x->x.value).(d.cards)):maximum((x->x.value).(d.cards))]
end

# ╔═╡ 48a4d802-2457-43a3-b586-4db0b7495a74
mutable struct Player
	hand::Union{Array{Card,1},Array{Int64,1}}
	Player() = new(
		Card[]
	)
	Player(numbers_only::Bool) = new(
		numbers_only ? Int64[] : Card[]
	)
	Player(hand::Array{Card,1}) = new(
		hand
	)
	Player(hand::Array{Int,1}) = new(
		hand
	)
	Player(hand::Array{Card,1}, numbers_only::Bool) = new(
		numbers_only ? valuesOnly(hand) : hand
	)
end

# ╔═╡ 24d37839-8f0d-4574-8d88-38deb492dd3b
mutable struct NamedPlayer
	name::Union{Int,String}
	player::Player
	NamedPlayer(name::Union{Int,String}, args...) = new(
		name,
		Player(args...)
	)
end

# ╔═╡ 16ad2016-a30c-4ad8-9f1d-173970b9953d
begin
	sumHand(p::Player) = sum(p.hand)
	sumHand(p::NamedPlayer) = sumHand(p.player)
end

# ╔═╡ 17336e5c-caff-4996-a942-be5fbde9a4a0
begin
	isBust(p::Player) = sumHand(p) > 21 ? true : false
	isBust(p::NamedPlayer) = isBust(p.player)
end

# ╔═╡ 83c232cf-b670-4939-8e7d-d8a40c4dd717
shuffleDeck(d::Deck) = begin
	d.drawpile = shuffle(d.drawpile)
end

# ╔═╡ 69aeb998-8627-4d37-8c42-c46ec312fecc
begin
	drawCard(d::Deck, p::Player) = begin
		if length(d.drawpile) >= 1
			if typeof(p.hand).parameters[1] == Card 
				push!(p.hand, pop!(d.drawpile))
			else
				push!(p.hand, pop!(d.drawpile).value)
			end
		end
	end
	drawCard(d::Deck, p::NamedPlayer) = drawCard(d, p.player)
end

# ╔═╡ f1596f96-ac65-445d-a7a9-5a4f65f6950a
begin
	topPlayedCard(d::Deck) = length(d.played_cards)>=1 ? d.played_cards[end].value : 0
	bottomPlayedCard(d::Deck) = length(d.played_cards)>=2 ? d.played_cards[1].value : 0
	nthPlayedCard(d::Deck, n::Int) = length(d.played_cards)>=n ? d.played_cards[end-n+1].value : 0
end

# ╔═╡ a493439a-cb3e-4801-be9e-aa627aaa014e
begin
	removeCardFromPlayer(p::Player, c::Card) = begin
		p.hand = filter((x->x!=c), p.hand)
	end
	removeCardFromPlayer(p::NamedPlayer, c::Card) = removeCardFromPlayer(p.player, c)
end

# ╔═╡ 00c872a9-15a6-4f66-842d-c55cb516638c
begin
	playCard(d::Deck, p::Player, c::Card) = begin
		push!(d.played_cards, c)
		removeCardFromPlayer(p, c)
	end
	playCard(d::Deck, p::NamedPlayer, c::Card) = playCard(d, p.player, c)
end

# ╔═╡ 022cd200-912c-465f-8e3b-7c3d63710cfc
begin
	addCardToBottom(d::Deck, p::Player, c::Card) = begin
		insert!(d.played_cards, 1, c)
		removeCardFromPlayer(p, c)
	end
	addCardToBottom(d::Deck, p::NamedPlayer, c::Card) = addCardToBottom(d, p.player, c)
end

# ╔═╡ 352c85f4-7cfc-4d1e-b0e3-6ff9e0ce026a
begin
	addDrawpileToHand(d::Deck, p::Player) = begin
		p.hand = vcat(p.hand, d.drawpile)
		d.drawpile = Card[]
	end
	addDrawpileToHand(d::Deck, p::NamedPlayer) = addDrawpileToHand(d, p.player)
end

# ╔═╡ 8ee77ce5-3883-4438-b243-3f00c3d34fdc
begin
	isBook(hand::Array{Card,1}) = length(hand)==4 ? sum((x->x.value==hand[1].value).(hand))==4 : false
	isBook(hand::Array{Int64,1}) = length(hand)==4 ? sum((x->x==hand[1]).(hand))==4 : false
end

# ╔═╡ 21a19a63-7b1c-46be-b554-e919c9f6cb2d
getCounts(hand::Array{Card,1}) = [sum((x->x.value==i).(hand)) for i in 1:13]

# ╔═╡ 089e701e-72ec-48a0-b708-e231ddd443d0
Base.convert(::Type{Int}, ::ReinforcementLearningCore.NoOp) = 0

# ╔═╡ 31c2a458-9911-4df3-a31f-3964b064e1da
skipPlayer(arr::Array) = duplicate(arr)[3:2+length(arr)]

# ╔═╡ f0ffdde6-961c-4b0e-998e-bfb7c72c4765
nextPlayer(arr::Array) = vcat(arr[2:end], arr[1])

# ╔═╡ b142f6e1-204d-41df-b63e-45474077600d
build_dueling_network(network::Chain) = begin
    lm = length(network)
    if !(network[lm] isa Dense) || !(network[lm-1] isa Dense) 
        error("The Qnetwork provided is incompatible with dueling.")
    end
    base = Chain([deepcopy(network[i]) for i=1:lm-2]...)
    last_layer_dims = size(network[lm].weight, 2)
    val = Chain(deepcopy(network[lm-1]), Dense(last_layer_dims, 1))
    adv = Chain([deepcopy(network[i]) for i=lm-1:lm]...)
    DuelingNetwork(base, val, adv)
end

# ╔═╡ 5ea3e327-0b0f-4803-b7fc-3780773ee91d
md"# Simple Blackjack"

# ╔═╡ a13e7b99-0926-4725-a0d5-76640604c7b3
md"""
**Note: In this simplified game, aces are always 1.**

##### Rules
 - Player gets 2 cards, dealer gets 1 (Player can see own 2 cards and dealer's first card)
 - At each turn the player must decide whether to hit (draw another card) or stand (end turn)
 - After each player turn, the dealer will draw a card
 - If the player stands, the dealer will draw cards until their sum is at least 17
 - The game ends when:
   - The dealer cannot draw any more cards
   - The dealer goes bust (total>21)
   - The player goes bust (total>21)
 - If the dealer goes bust, player wins; if the player goes bust, dealer wins
 - If neither player nor dealer goes bust, the highest point value wins
   - If player goes bust or loses, reward is -1
   - If player wins with <21, reward is 1
   - If player wins with 21, reward is 2
 - Player can see total value of own hand and dealer's hand

"""

# ╔═╡ 1f1ff71a-8864-4d54-9bfe-c121cdcb13b3
begin

	mutable struct SimpleBlackjackEnv <: AbstractEnv
		deck::Deck
		dealer::Player
		player::Player
		is_terminated::Bool
		SimpleBlackjackEnv() = begin
			deck = Deck(DeckTypes[:StandardNoJokersFace10])
			shuffleDeck(deck)
			player = Player(true)
			dealer = Player(true)
			drawCard(deck, player)
			drawCard(deck, dealer)
			drawCard(deck, player)
			new(
				deck,
				player,
				dealer,
				false
			)
		end
	end

	RLBase.action_space(env::SimpleBlackjackEnv) = [
		0, # stand
		1 # hit
	]

	RLBase.legal_action_space(env::SimpleBlackjackEnv) = [0, 1]

	RLBase.legal_action_space_mask(env::SimpleBlackjackEnv) = [true, true]

	RLBase.reward(env::SimpleBlackjackEnv) = is_terminated(env) ? begin
		sumHand(env.player) == 21 ? 2 : 
		sumHand(env.player) < 21 && sumHand(env.player)>sumHand(env.dealer) ? 1 : 
		-1
	end : 0

	RLBase.state(env::SimpleBlackjackEnv) = [sumHand(env.player), sumHand(env.dealer)]

	RLBase.state_space(env::SimpleBlackjackEnv) = [[i, j] for i in 1:30 for j in 1:30]

	RLBase.is_terminated(env::SimpleBlackjackEnv) = env.is_terminated

	RLBase.reset!(env::SimpleBlackjackEnv) = begin
		deck = Deck(DeckTypes[:StandardNoJokersFace10])
		shuffleDeck(deck)
		player = Player(true)
		dealer = Player(true)
		drawCard(deck, player)
		drawCard(deck, dealer)
		drawCard(deck, player)
		env.deck = deck
		env.player = player
		env.dealer = dealer
		env.is_terminated = false
	end

	(env::SimpleBlackjackEnv)(action::Int64) = begin
		if action == 0
			while sumHand(env.dealer) < 17
				drawCard(env.deck, env.dealer)
			end
			env.is_terminated = true
		elseif action == 1
			drawCard(env.deck, env.player)
			if sumHand(env.player) > 21
				env.is_terminated = true
			else
				if sumHand(env.dealer) < 17
					drawCard(env.deck, env.dealer)
				end
				if sumHand(env.dealer) >= 17
					env.is_terminated = true
				end
			end
		else
			@error "Invalid action"
		end
		if sumHand(env.dealer) >= 17 || sumHand(env.player) >= 21
			env.is_terminated = true
		end
	end

	RLBase.NumAgentStyle(::SimpleBlackjackEnv) = SINGLE_AGENT
	RLBase.DynamicStyle(::SimpleBlackjackEnv) = SEQUENTIAL
	RLBase.ActionStyle(::SimpleBlackjackEnv) = FULL_ACTION_SET
	RLBase.InformationStyle(::SimpleBlackjackEnv) = PERFECT_INFORMATION
	RLBase.StateStyle(::SimpleBlackjackEnv) = Observation{Array{Int64,1}}()
	RLBase.RewardStyle(::SimpleBlackjackEnv) = TERMINAL_REWARD
	RLBase.ChanceStyle(::SimpleBlackjackEnv) = STOCHASTIC

end

# ╔═╡ a409819b-6362-4090-a5f3-e53ed0611400
md"# Single-Player ERS"

# ╔═╡ 242cc5fb-c0e0-4288-8628-b5618d532019
md"""
The purpose of this environment is to test how quickly agents can learn rules

##### Rules
 - Player will place one card face up
 - n other "players" will continue to place cards face up
   - Players is in quotes because they will only play cards, not try to win the game
 - Player can choose to hit/wait after each turn
   - If a player hits correctly, they will receive all of the cards in the pile; a hit is valid if:
      - Top two cards are the same value
      - Top card and 3rd card are the same value (X-Y-X...)
      - Top card and bottom card are the same value
      - Top two cards are king and queen (order does not matter)
      - Top two cards add to 10
   - If a player hits incorrectly, they will put one card from their hand into the pile
 - If a player places a face card (A, K, Q, J), the next player must play either 4(A), 3(K), 2(Q), 1(J) cards. If the next player does not play a face card before the limit, the previous player gets the pile.
 - Player wins the game by accumulating all of the cards
 - Reward will be determined by the number of cards the player has after 10 turns
"""

# ╔═╡ ca9fa214-5bf3-4552-aed8-76d015e4ea37
begin

	mutable struct SinglePlayerERSEnv <: AbstractEnv
		deck::Deck
		player::Player
		other_players::Array{Player,1}
		num_turns::Int64
		is_terminated::Bool
		current_player::Int64
		SinglePlayerERSEnv(n_other_players::Int) = begin
			deck = Deck(DeckTypes[:StandardNoJokersAceHighest])
			shuffleDeck(deck)
			player = Player()
			other_players = [Player() for i in 1:n_other_players]
			while length(deck.drawpile)>0
				drawCard(deck, player)
				for i in 1:n_other_players
					drawCard(deck, other_players[i])
				end
			end
			new(
				deck,
				player,
				other_players,
				0,
				false,
				0
			)
		end
	end
	slapIsValid(env::SinglePlayerERSEnv) = (
		topPlayedCard(env.deck) == bottomPlayedCard(env.deck) || 
		topPlayedCard(env.deck) == nthPlayedCard(env.deck, 2) ||
		topPlayedCard(env.deck) == nthPlayedCard(env.deck, 3) ||
		sort([topPlayedCard(env.deck), nthPlayedCard(env.deck, 2)]) == [12, 13] ||
		topPlayedCard(env.deck)+nthPlayedCard(env.deck, 2) == 10
	)

	RLBase.action_space(env::SinglePlayerERSEnv) = [
		0, # wait
		1 # hit
	]

	RLBase.legal_action_space(env::SinglePlayerERSEnv) = [0, 1]

	RLBase.legal_action_space_mask(env::SinglePlayerERSEnv) = [true, true]

	RLBase.reward(env::SinglePlayerERSEnv) = is_terminated(env) ? length(env.player.hand) : 0

	RLBase.state(env::SinglePlayerERSEnv) = [
		bottomPlayedCard(env.deck),
		nthPlayedCard(env.deck, 3),
		nthPlayedCard(env.deck, 2),
		topPlayedCard(env.deck)
	]

	RLBase.state_space(env::SinglePlayerERSEnv) = [
		[i, j, k, l]
		for i in vcat(0, 2:14)
		for j in vcat(0, 2:14)
		for k in vcat(0, 2:14)
		for l in vcat(0, 2:14)
	]

	RLBase.is_terminated(env::SinglePlayerERSEnv) = env.is_terminated || env.num_turns>10

	RLBase.reset!(env::SinglePlayerERSEnv) = begin
		n_other_players = length(env.other_players)
		deck = Deck(DeckTypes[:StandardNoJokersAceHighest])
		shuffleDeck(deck)
		player = Player()
		other_players = [Player() for i in 1:n_other_players]
		while length(deck.drawpile)>0
			drawCard(deck, player)
			for i in 1:n_other_players
				drawCard(deck, other_players[i])
			end
		end
		env.deck = deck
		env.player = player
		env.other_players = other_players
		env.num_turns = 0
		env.is_terminated = false
		env.current_player = 0
	end

	(env::SinglePlayerERSEnv)(action::Int64) = begin
		env.num_turns += 1
		if env.current_player == 0
			if length(env.player.hand) >= 1
				playCard(env.deck, env.player, env.player.hand[1])
			end
		else
			if length(env.other_players[env.current_player].hand) >= 1
				playCard(env.deck, env.other_players[env.current_player], env.other_players[env.current_player].hand[1])
			end
		end
		if topPlayedCard(env.deck) > 10
			env.current_player += 1
			env.current_player = (env.current_player)%(length(env.other_players)+1)
			p = env.current_player == 0 ? env.player : env.other_players[env.current_player]
			for i in 1:topPlayedCard(env.deck)-10
				if length(p.hand) >= 1
					playCard(env.deck, p, p.hand[1])
				end
				while topPlayedCard(env.deck) > 10
					env.current_player += 1
					env.current_player = (env.current_player)%(length(env.other_players)+1)
					p = env.current_player == 0 ? env.player : env.other_players[env.current_player]
					for i in 1:topPlayedCard(env.deck)-10
						if length(p.hand) >= 1
							playCard(env.deck, p, p.hand[1])
						end
						if topPlayedCard(env.deck) > 10
							break
						end
					end
					if topPlayedCard(env.deck) > 10
						break
					end
				end
				if topPlayedCard(env.deck) > 10
					break
				end
			end
			env.current_player = (length(env.other_players)+env.current_player)%(length(env.other_players)+1)
			env.current_player == 0 ? addDrawpileToHand(env.deck, env.player) : addDrawpileToHand(env.deck, env.other_players[env.current_player])
		end
		if action == 0
			env.current_player += 1
		elseif action == 1
			if slapIsValid(env)
				addDrawpileToHand(env.deck, env.player)
				env.current_player = 0
			else
				if length(env.player.hand) >= 1
					addCardToBottom(env.deck, env.player, env.player.hand[1])
				end
				env.current_player += 1
			end
		else
			@error "Invalid action"
		end
		if length(env.player.hand) == 52 
			env.is_terminated = true
		end
		env.current_player = (env.current_player)%(length(env.other_players)+1)
	end

	RLBase.NumAgentStyle(::SinglePlayerERSEnv) = SINGLE_AGENT
	RLBase.DynamicStyle(::SinglePlayerERSEnv) = SEQUENTIAL
	RLBase.ActionStyle(::SinglePlayerERSEnv) = FULL_ACTION_SET
	RLBase.InformationStyle(::SinglePlayerERSEnv) = PERFECT_INFORMATION
	RLBase.StateStyle(::SinglePlayerERSEnv) = Observation{Array{Int64,1}}()
	RLBase.RewardStyle(::SinglePlayerERSEnv) = TERMINAL_REWARD
	RLBase.ChanceStyle(::SinglePlayerERSEnv) = STOCHASTIC

end

# ╔═╡ 8840ffef-75c5-4a72-b04e-6bf2010fc769
md"# Modified Spoons"

# ╔═╡ b254d9ae-4433-4a77-a5dc-2f6bb14d4dce
md"""
##### Rules
 - This is a single-player modification of the game Spoons focused only on the card-passing aspect of the game
 - Player will have 4 cards
 - At each turn, player will get a card and then pass one card to the bottom of the drawpile
 - The game will end when the player creates a "book" (all 4 cards in the hand have the same value)
 - Reward will be determined by how many cards are the same
"""

# ╔═╡ d89e225d-cbe6-43e9-b6e5-3ce72dcc4904
begin

	mutable struct ModifiedSpoonsEnv <: AbstractEnv
		deck::Deck
		player::Player
		num_turns::Int
		is_terminated::Bool
		ModifiedSpoonsEnv() = begin
			deck = Deck(DeckTypes[:StandardNoJokers])
			shuffleDeck(deck)
			player = Player()
			for i in 1:5
				drawCard(deck, player)
			end
			new(
				deck,
				player,
				0,
				false
			)
		end
	end

	RLBase.action_space(env::ModifiedSpoonsEnv) = [1, 2, 3, 4, 5]

	RLBase.legal_action_space(env::ModifiedSpoonsEnv) = [1, 2, 3, 4, 5]

	RLBase.legal_action_space_mask(env::ModifiedSpoonsEnv) = [true, true, true, true, true]

	RLBase.reward(env::ModifiedSpoonsEnv) = is_terminated(env) ? maximum([count(x->x.value==i, env.player.hand) for i in 1:13]) : 0

	RLBase.state(env::ModifiedSpoonsEnv) = sort(valuesOnly(env.player.hand))

	RLBase.state_space(env::ModifiedSpoonsEnv) = [
		[i, j, k, l, m]
		for i in 1:13
		for j in i:13
		for k in j:13
		for l in k:13
		for m in l:13
	]

	RLBase.is_terminated(env::ModifiedSpoonsEnv) = env.is_terminated

	RLBase.reset!(env::ModifiedSpoonsEnv) = begin
		deck = Deck(DeckTypes[:StandardNoJokers])
		shuffleDeck(deck)
		player = Player()
		for i in 1:5
			drawCard(deck, player)
		end
		env.deck = deck
		env.player = player
		env.num_turns = 0
		env.is_terminated = false
	end

	(env::ModifiedSpoonsEnv)(action::Int64) = begin
		if env.num_turns >= 1000
			env.is_terminated = true
		end
		if !is_terminated(env)
			if 1 ≤ action ≤ 5
				playCard(env.deck, env.player, env.player.hand[action])
			else
				@error "Invalid action"
			end
			if isBook(valuesOnly(env.player.hand[1:4]))
				env.is_terminated = true
			else
				env.num_turns += 1
			end
			while length(env.player.hand) < 5
				drawCard(env.deck, env.player)
				if length(env.deck.drawpile)==0
					env.deck.drawpile = env.deck.played_cards
				end
			end
		end
	end

	RLBase.NumAgentStyle(::ModifiedSpoonsEnv) = SINGLE_AGENT
	RLBase.DynamicStyle(::ModifiedSpoonsEnv) = SEQUENTIAL
	RLBase.ActionStyle(::ModifiedSpoonsEnv) = FULL_ACTION_SET
	RLBase.InformationStyle(::ModifiedSpoonsEnv) = PERFECT_INFORMATION
	RLBase.StateStyle(::ModifiedSpoonsEnv) = Observation{Array{Int64,1}}()
	RLBase.RewardStyle(::ModifiedSpoonsEnv) = TERMINAL_REWARD
	RLBase.ChanceStyle(::ModifiedSpoonsEnv) = STOCHASTIC

end

# ╔═╡ 540f5bbf-24e1-4e35-8523-562e2f103276
md"# Strategic War"

# ╔═╡ 7cc6194e-53ae-4589-8f9b-c1de5ee3361e
md"""
##### Rules
 - Player1 and Player2 receive 26 cards each
 - At each turn:
   - Player1 and Player2 will play a card simultaneously
   - The player who placed the higher value card will receive a point
   - The played cards will be discarded
 - The reward of a player is how many points they have when all 52 cards have been played
 - State will be represented by an array of the number of cards of each number a player has
"""

# ╔═╡ a78fbe62-f76b-43ff-a818-aa9f132a6bae
begin
	const PLAYER1 = 1
	const PLAYER2 = 2
	mutable struct StrategicWarEnv <: AbstractEnv
		deck::Deck
		player1::Player
		player2::Player
		most_recent_played_card::Union{Nothing,Card}
		scores::Array{Int,1}
		is_terminated::Bool
		StrategicWarEnv() = begin
			deck = Deck(DeckTypes[:StandardNoJokers])
			shuffleDeck(deck)
			p1 = Player()
			p2 = Player()
			for i in 1:26
				drawCard(deck, p1)
				drawCard(deck, p2)
			end
			new(
				deck,
				p1,
				p2,
				nothing,
				[0, 0],
				false
			)
		end
	end

	RLBase.action_space(env::StrategicWarEnv, ::Int64) = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

	RLBase.legal_action_space(env::StrategicWarEnv, p::Int64) = findall(legal_action_space_mask(env, p))

	RLBase.legal_action_space_mask(env::StrategicWarEnv, p::Int64) = begin
		counts = getCounts([env.player1.hand, env.player2.hand][p])
		[counts[i]≥1 for i in 1:13]
	end

	RLBase.reward(env::StrategicWarEnv, p::Int64) = is_terminated(env) ? env.scores[p] : 0

	RLBase.state(env::StrategicWarEnv) = getCounts(typeof(env.most_recent_played_card)==Nothing ? env.player1.hand : env.player2.hand)
	RLBase.state(env::StrategicWarEnv, ::Observation{Array{Int64,1}}, p::Int64) = getCounts([env.player1.hand, env.player2.hand][p])

	RLBase.state_space(env::StrategicWarEnv) = Space(0..4 for i in 1:13)

	RLBase.is_terminated(env::StrategicWarEnv) = env.is_terminated

	RLBase.reset!(env::StrategicWarEnv) = begin
		deck = Deck(DeckTypes[:StandardNoJokers])
		shuffleDeck(deck)
		p1 = Player()
		p2 = Player()
		for i in 1:26
			drawCard(deck, p1)
			drawCard(deck, p2)
		end
		env.deck = deck
		env.player1 = p1
		env.player2 = p2
		env.most_recent_played_card = nothing
		env.scores = [0, 0]
		env.is_terminated = false
	end

	RLBase.players(env::StrategicWarEnv) = (PLAYER1, PLAYER2)
	RLBase.current_player(env::StrategicWarEnv) = typeof(env.most_recent_played_card)==Nothing ? PLAYER1 : PLAYER2

	(env::StrategicWarEnv)(action::Union{NoOp,Int64}, p::Int64) = begin
		if typeof(action) != NoOp && 1≤action≤13
			if p == PLAYER1
				played_card = [i for i in env.player1.hand if i.value==action][1]
				removeCardFromPlayer(env.player1, played_card)
				env.most_recent_played_card = played_card
			elseif p == PLAYER2
				try
					played_card = [i for i in env.player2.hand if i.value==action][1]
					removeCardFromPlayer(env.player2, played_card)
				catch
					played_card = env.player2.hand[1]
					removeCardFromPlayer(env.player2, played_card)
				end
				if played_card.value > env.most_recent_played_card.value
					env.scores[PLAYER2] += 1
				elseif played_card.value < env.most_recent_played_card.value
					env.scores[PLAYER1] += 1
				end
				env.most_recent_played_card = nothing
			else
				@error "Wrong player chosen"
			end
			if length(env.player2.hand) == 0
				env.is_terminated = true
			end
		end
	end

	RLBase.NumAgentStyle(::StrategicWarEnv) = MultiAgent(2)
	RLBase.DynamicStyle(::StrategicWarEnv) = SEQUENTIAL
	RLBase.ActionStyle(::StrategicWarEnv) = FULL_ACTION_SET
	RLBase.InformationStyle(::StrategicWarEnv) = IMPERFECT_INFORMATION
	RLBase.StateStyle(::StrategicWarEnv) = Observation{Array{Int64,1}}()
	RLBase.RewardStyle(::StrategicWarEnv) = TERMINAL_REWARD
	RLBase.ChanceStyle(::StrategicWarEnv) = STOCHASTIC

end

# ╔═╡ d6dc4b56-7522-41ed-9d4d-9dfcf338c1ab
md"# UNO"

# ╔═╡ 81b701a5-35ad-44c2-ab5f-7c6e977ba2ed
md"""
##### Rules
 - Each player receives 7 cards to start
 - At each turn, if a player has a playable card (same color/value of top card or wild), that player must play it
 - If a player does not have a playable card, they must draw a card
   - If the drawn card is playable, they must play it
 - Some cards have powerups (for the sake of simplicity, wild will always switch to the color that the player who played it has the most cards of)
 - The first player to run out of cards wins
"""

# ╔═╡ 4b9fbfe2-670c-4f7c-8a75-2a790335b3a3
begin

	const CardToNum = Dict(
		Deck(DeckTypes[:StandardUno]).cards[i] => i
		for i in 1:108
	)
	const NumToCard = Dict(
		i.second => i.first
		for i in CardToNum
	)
	
	mutable struct UnoEnv <: AbstractEnv
		deck::Deck
		players::Array{NamedPlayer,1}
		most_recent_played_card::Card
		is_terminated::Bool
		UnoEnv(n::Int64) = begin
			deck = Deck(DeckTypes[:StandardUno])
			shuffleDeck(deck)
			players = [NamedPlayer(i) for i in 1:n]
			for i in 1:min(7, Int(floor(108/n)))
				for p in players
					drawCard(deck, p)
				end
			end
			drawCard(deck, players[1])
			playCard(deck, players[1], players[1].player.hand[end])
			new(
				deck,
				players,
				deck.played_cards[1],
				false
			)
		end
	end

	RLBase.action_space(env::UnoEnv, ::Int64) = 0:length(env.deck.cards)

	RLBase.legal_action_space(env::UnoEnv, p::Int64) = findall(legal_action_space_mask(env, p))

	RLBase.legal_action_space_mask(env::UnoEnv, ::Int64) = begin
		cards = broadcastDict(CardToNum, env.players[1].player.hand)
		a = vcat([false], [i in cards for i in 1:108 if isValidUNOCard(env.most_recent_played_card, NumToCard[i])])
		if sum(a) == 0
			a[1] = true
		end
		a
	end

	RLBase.reward(env::UnoEnv, p::Int64) = is_terminated(env) ? 7 - length(sort(env.players, by=identity.name)[p].hand) : 0

	RLBase.state(env::UnoEnv) = [length(i.player.hand) for i in env.players]
	RLBase.state(env::UnoEnv, ::Observation{Array{Int64,1}}, p::Int64) = state(env)

	RLBase.state_space(env::UnoEnv) = Space(0..108 for i in 1:length(env.players))

	RLBase.is_terminated(env::UnoEnv) = env.is_terminated

	RLBase.reset!(env::UnoEnv) = begin
		deck = Deck(DeckTypes[:StandardUno])
		players = [NamedPlayer(i) for i in 1:length(env.players)]
		for i in 1:min(7, Int(floor(108/length(env.players))))
			for p in players
				drawCard(deck, p)
			end
		end
		drawCard(deck, players[1])
		playCard(deck, players[1], players[1].player.hand[end])
		env.deck = deck
		env.players = players
		env.most_recent_played_card = deck.played_cards[1]
		env.is_terminated = false
	end

	RLBase.players(env::UnoEnv) = [i for i in 1:length(env.players)]
	RLBase.current_player(env::UnoEnv) = env.players[1].name

	isValidUNOCard(topCard::Card, cardToPlay::Card) = begin
		if cardToPlay.suit != "black"
			topCard.name==cardToPlay.name || topCard.suit==cardToPlay.suit
		else
			true
		end
	end
	(env::UnoEnv)(action::Union{NoOp,Int64}, p::Int64) = begin
		if action == 0
			drawCard(env.deck, env.players[1].player)
			env.players = nextPlayer(env.players)
		elseif typeof(action) != NoOp && isValidUNOCard(env.most_recent_played_card, NumToCard[action])
			if typeof(NumToCard[action].special) != Nothing
				env.most_recent_played_card = NumToCard[action]
				playCard(env.deck, env.players[1].player, NumToCard[action])
				env.players = nextPlayer(env.players)
			else
				if NumToCard[action].special == "+2"
					env.most_recent_played_card = NumToCard[action]
					playCard(env.deck, env.players[1].player, NumToCard[action])
					drawCard(env.deck, env.players[2].player)
					drawCard(env.deck, env.players[2].player)
					env.players = nextPlayer(env.players)
				elseif NumToCard[action].special == "reverse"
					env.most_recent_played_card = NumToCard[action]
					playCard(env.deck, env.players[1].player, NumToCard[action])
					env.players = reverse(env.players)
				elseif NumToCard[action].special == "wild"
					c = rand(env.players[1].player.hand)
					playCard(env.deck, env.players[1].player, c)
					env.players = nextPlayer(env.players)
				elseif NumToCard[action].special == "wild+4"
					c = rand(env.players[1].player.hand)
					playCard(env.deck, env.players[1].player, c)
					for i in 1:4
						drawCard(env.deck, env.players[2].player)
					end
					env.players = nextPlayer(env.players)
				end
			end
		else
			@error "Invalid action"
		end
	end

	RLBase.NumAgentStyle(env::UnoEnv) = MultiAgent(length(env.players))
	RLBase.DynamicStyle(::UnoEnv) = SEQUENTIAL
	RLBase.ActionStyle(::UnoEnv) = FULL_ACTION_SET
	RLBase.InformationStyle(::UnoEnv) = IMPERFECT_INFORMATION
	RLBase.StateStyle(::UnoEnv) = Observation{Array{Int64,1}}()
	RLBase.RewardStyle(::UnoEnv) = TERMINAL_REWARD
	RLBase.ChanceStyle(::UnoEnv) = STOCHASTIC
end

# ╔═╡ 4fd96db9-744e-49a4-af11-ee2e192f1e7a
run_MultiAgent(policy::AbstractPolicy, env::AbstractEnv, stop_condition, hook::AbstractHook) = begin
	hook(PRE_EXPERIMENT_STAGE, policy, env)
    policy(PRE_EXPERIMENT_STAGE, env)
    is_stop = false
    while !is_stop
        reset!(env)
        hook(PRE_EPISODE_STAGE, policy, env)
        while !is_terminated(env)
            action = policy(env)
            env(action)
            policy(POST_ACT_STAGE, env)
            hook(POST_ACT_STAGE, policy, env)
            if stop_condition(policy, env)
                is_stop = true
                break
            end
        end
        if is_terminated(env)
            hook(POST_EPISODE_STAGE, policy, env)
        end
    end
    hook(POST_EXPERIMENT_STAGE, policy, env)
    hook
end

# ╔═╡ 20e8c928-decf-44c1-884d-0dc393b102bd
test_SimpleBlackjackEnv() = begin
	env = discrete2standard_discrete(SimpleBlackjackEnv())
	rng = StableRNG(3435)
	n_steps = N_STEPS
	ns, na = length(state(env)), length(action_space(env))
	policy = Agent(
		policy = QBasedPolicy(
			learner = BasicDQNLearner(
				approximator = NeuralNetworkApproximator(
					model = Chain(
						Dense(ns, 32, relu; init = glorot_uniform(rng)),
						Dense(32, 64, relu; init = glorot_uniform(rng)),
						Dense(64, 128, relu; init = glorot_uniform(rng)),
						Dense(128, 128, relu; init = glorot_uniform(rng)),
						Dense(128, 64, relu; init = glorot_uniform(rng)),
						Dense(64, 32, relu; init = glorot_uniform(rng)),
						Dense(32, na; init = glorot_uniform(rng))
					) |> gpu,
					optimizer = ADAM(),
				),
				batch_size = 16,
				min_replay_history = n_steps/10,
				loss_func = huber_loss,
				rng = rng,
			),
			explorer = EpsilonGreedyExplorer(
				kind = :linear,
				ϵ_stable = 0.0,
				decay_steps = n_steps,
				rng = rng,
			),
		),
		trajectory = CircularArraySARTTrajectory(
			capacity = n_steps,
			state = Vector{Int64} => (ns,),
		),
	)
	stop_condition = StopAfterEpisode(n_steps, is_show_progress=true)
	hook = TotalRewardPerEpisode()
	run(policy, env, stop_condition, hook)
	rewards = hook.rewards
	rewards
end

# ╔═╡ 4efebd67-6cc4-44bc-a694-8b0fe32833a0
rewards_blackjack = test_SimpleBlackjackEnv()

# ╔═╡ de640be9-5d65-400a-ab7a-a058b52e3f77
plot(moving_average(rewards_blackjack, convert(Int, N_STEPS/10)), legend=false)

# ╔═╡ efb8321e-7fa9-412c-9944-f168ab181aef
test_SinglePlayerERSEnv(n::Int) = begin
	env = discrete2standard_discrete(SinglePlayerERSEnv(n))
	rng = StableRNG(3435)
	n_steps = N_STEPS
	ns, na = length(state(env)), length(action_space(env))
	policy = Agent(
		policy = QBasedPolicy(
			learner = BasicDQNLearner(
				approximator = NeuralNetworkApproximator(
					model = Chain(
						Dense(ns, 64, relu; init = glorot_uniform(rng)),
						Dense(64, 64, relu; init = glorot_uniform(rng)),
						Dense(64, na; init = glorot_uniform(rng))
					) |> gpu,
					optimizer = ADAM(),
				),
				batch_size = 16,
				min_replay_history = n_steps/10,
				loss_func = huber_loss,
				rng = rng,
			),
			explorer = EpsilonGreedyExplorer(
				kind = :linear,
				ϵ_stable = 0.0,
				decay_steps = n_steps,
				rng = rng,
			),
		),
		trajectory = CircularArraySARTTrajectory(
			capacity = N_STEPS,
			state = Vector{Int64} => (ns,),
		),
	)
	stop_condition = StopAfterEpisode(n_steps, is_show_progress=true)
	hook = TotalRewardPerEpisode()
	run(policy, env, stop_condition, hook)
	rewards = hook.rewards
	rewards
end

# ╔═╡ 13f91d3d-7cca-4181-82f9-de0daa7c5a38
begin
	rewards_ERS = test_SinglePlayerERSEnv(3)
	plot(moving_average(rewards_ERS, convert(Int, length(rewards_ERS)/10)), legend=false)
end

# ╔═╡ 0b8dcd2c-ad42-4af8-817f-227a16fc30ae
test_ModifiedSpoonsEnv() = begin
	env = discrete2standard_discrete(ModifiedSpoonsEnv())
	rng = StableRNG(3435)
	n_steps = Int(N_STEPS/20)
	ns, na = length(state(env)), length(action_space(env))
	policy = Agent(
		policy = QBasedPolicy(
			learner = BasicDQNLearner(
				approximator = NeuralNetworkApproximator(
					model = Chain(
						Dense(ns, 64, relu; init = glorot_uniform(rng)),
						Dense(64, 64, relu; init = glorot_uniform(rng)),
						Dense(64, na; init = glorot_uniform(rng))
					) |> gpu,
					optimizer = ADAM(),
				),
				batch_size = 16,
				min_replay_history = n_steps,
				loss_func = huber_loss,
				rng = rng,
			),
			explorer = EpsilonGreedyExplorer(
				kind = :linear,
				ϵ_stable = 0.0,
				decay_steps = n_steps,
				rng = rng,
			),
		),
		trajectory = CircularArraySARTTrajectory(
			capacity = 1000,
			state = Vector{Int64} => (ns,),
		),
	)
	stop_condition = StopAfterEpisode(n_steps, is_show_progress=true)
	hook = TotalRewardPerEpisode()
	run(policy, env, stop_condition, hook)
	rewards = hook.rewards
	rewards
end

# ╔═╡ 1d568e15-6f9c-46b8-92b9-e8ab9c22a209
rewards_SPOONS = test_ModifiedSpoonsEnv()

# ╔═╡ 9ba7873c-76b5-42f0-875e-5ea6131fccd1
plot(moving_average(rewards_SPOONS, convert(Int, length(rewards_SPOONS)/10)), legend=false)

# ╔═╡ a287598b-a57b-4a5a-9781-41458819f9a1
test_StrategicWarEnv() = begin
	env = ActionTransformedEnv(discrete2standard_discrete(StrategicWarEnv()))
	rng = StableRNG(3435)
	n_steps = N_STEPS
	ns, na = length(state(env, PLAYER1)), length(action_space(env, PLAYER1))
	base_model = Chain(
        Dense(ns, 64, relu; init = glorot_uniform(rng)),
        Dense(64, 64, relu; init = glorot_uniform(rng)),
        Dense(64, na; init = glorot_uniform(rng))
	)  
	agents = MultiAgentManager(
		(
			Agent(
				policy = NamedPolicy(
					1 => QBasedPolicy(;
						learner = DQNLearner(
							approximator = NeuralNetworkApproximator(
								model = build_dueling_network(base_model),
								optimizer = ADAM(),
							),
							target_approximator = NeuralNetworkApproximator(
								model = build_dueling_network(base_model),
							),
							loss_func = huber_loss,
							stack_size = nothing,
							batch_size = 32,
							update_horizon = 1,
							min_replay_history = 1,
							update_freq = 1,
							target_update_freq = 1,
							rng = rng,
							traces = SLARTSL
						),
						explorer = EpsilonGreedyExplorer(
							kind = :linear,
							ϵ_stable = 0.0,
							decay_steps = n_steps,
							rng = rng,
						),
					)
				),
				trajectory = CircularArraySLARTTrajectory(
					capacity = n_steps,
					state = Array{Int,1} => (ns,),
					legal_actions_mask = Array{Int,1} => (8,),
				)
			)
			,#,for p in [1],#players(env),
			Agent(
				policy = NamedPolicy(2 => RandomPolicy(legal_action_space(env))),
				trajectory = CircularArraySLARTTrajectory(
					capacity = 1000,
					state = Array{Int,1} => (ns,),
					legal_actions_mask = Array{Int,1} => (8,),
				)
			)
		)...
	)
	multi_agent_hook = MultiAgentHook(
		(
			p => TotalRewardPerEpisode()
			for p in players(env)
		)...
	)
	stop_condition = StopAfterEpisode(n_steps)
	rewards = run_MultiAgent(agents, env, stop_condition, multi_agent_hook)
	rewards = rewards.hooks
	rewards = [rewards[1].rewards, rewards[2].rewards]
	rewards
end

# ╔═╡ da7e7ddb-30f5-4cc8-94db-573719a18cff
begin
	rewards1, rewards2 = test_StrategicWarEnv()
	plot(moving_average(rewards1, Int(length(rewards1)/10)), legend=false)
end

# ╔═╡ f24feca5-eca6-4d0f-8554-49b202eafde9
test_UnoEnv(n) = begin
	env = ActionTransformedEnv(discrete2standard_discrete(UnoEnv(n)))
	rng = StableRNG(3435)
	n_steps = N_STEPS
	ns, na = length(state(env, 1)), length(action_space(env, 1))
	base_model = Chain(
        Dense(ns, 64, relu; init = glorot_uniform(rng)),
        Dense(64, 64, relu; init = glorot_uniform(rng)),
        Dense(64, na; init = glorot_uniform(rng))
	)  
	agents = MultiAgentManager(
		(
			#=
			Agent(
				policy = NamedPolicy(
					1 => QBasedPolicy(;
						learner = DQNLearner(
							approximator = NeuralNetworkApproximator(
								model = build_dueling_network(base_model),
								optimizer = ADAM(),
							),
							target_approximator = NeuralNetworkApproximator(
								model = build_dueling_network(base_model),
							),
							loss_func = huber_loss,
							stack_size = nothing,
							batch_size = 32,
							update_horizon = 1,
							min_replay_history = 1,
							update_freq = 1,
							target_update_freq = 1,
							rng = rng,
							traces = SLARTSL
						),
						explorer = EpsilonGreedyExplorer(
							kind = :linear,
							ϵ_stable = 0.0,
							decay_steps = n_steps,
							rng = rng,
						),
					)
				),
				trajectory = CircularArraySLARTTrajectory(
					capacity = n_steps,
					state = Array{Int,1} => (ns,),
					legal_actions_mask = Array{Int,1} => (109,),
				)
			)
			,=#
			(Agent(
				policy = NamedPolicy(i => RandomPolicy(legal_action_space(env))),
				trajectory = CircularArraySLARTTrajectory(
					capacity = 1000,
					state = Array{Int,1} => (ns,),
					legal_actions_mask = Array{Int,1} => (109,),
				)
			) for i in 1:n)...,
		)...
	)
	multi_agent_hook = MultiAgentHook(
		(
			p => TotalRewardPerEpisode()
			for p in players(env)
		)...
	)
	stop_condition = StopAfterEpisode(n_steps)
	rewards = run_MultiAgent(agents, env, stop_condition, multi_agent_hook)
	rewards = rewards.hooks
	rewards = [rewards[i].rewards for i in rewards]
	rewards
end

# ╔═╡ f504756f-1e09-4184-bb4b-9674e35d9167
RLBase.test_runnable!(UnoEnv(3)) # if this runs, the environment works

# ╔═╡ a3474b63-514a-4dd4-8c2b-b6a1521fa011
md"# Libraries Used (References)"

# ╔═╡ 6b990c1d-99d0-4dee-99fb-31cfa216f22f
md"""
```
@article{bezanson2017julia,
  title        = {Julia: A fresh approach to numerical computing},
  author       = {Bezanson, Jeff and Edelman, Alan and Karpinski, Stefan and Shah, Viral B},
  journal      = {SIAM review},
  volume       = {59},
  number       = {1},
  pages        = {65--98},
  year         = {2017},
  publisher    = {SIAM},
  url          = {https://doi.org/10.1137/141000671}
}
@misc{Tian2020Reinforcement,
  author       = {Jun Tian and other contributors},
  title        = {ReinforcementLearning.jl: A Reinforcement Learning Package for the Julia Programming Language},
  year         = 2020,
  url          = {https://github.com/JuliaReinforcementLearning/ReinforcementLearning.jl}
}

@article{Flux.jl-2018,
  author    = {Michael Innes and
               Elliot Saba and
               Keno Fischer and
               Dhairya Gandhi and
               Marco Concetto Rudilosso and
               Neethu Mariya Joy and
               Tejan Karmali and
               Avik Pal and
               Viral Shah},
  title     = {Fashionable Modelling with Flux},
  journal   = {CoRR},
  volume    = {abs/1811.01457},
  year      = {2018},
  url       = {https://arxiv.org/abs/1811.01457},
  archivePrefix = {arXiv},
  eprint    = {1811.01457},
  timestamp = {Thu, 22 Nov 2018 17:58:30 +0100},
  biburl    = {https://dblp.org/rec/bib/journals/corr/abs-1811-01457},
  bibsource = {dblp computer science bibliography, https://dblp.org}
}

@article{innes:2018,
  author    = {Mike Innes},
  title     = {Flux: Elegant Machine Learning with Julia},
  journal   = {Journal of Open Source Software},
  year      = {2018},
  doi       = {10.21105/joss.00602},
}

@misc{
  author    = {Invenia Technical Computing},
  title     = {Intervals},
  year      = {2020},
  url       = {https://github.com/invenia/Intervals.jl}
}

@misc{
  author    = {"Rafael Fourquet <fourquet.rafael@gmail.com>"},
  title     = {StableRNGs},
  year      = {2020},
  url       = {https://github.com/JuliaRandom/StableRNGs.jl},
}

@misc{
  author    = {"Tom Breloff (@tbreloff)"},
  title     = {Plots},
  year      = {2021},
  url       = {https://github.com/JuliaPlots/Plots.jl},
}
```
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Flux = "587475ba-b771-5e3f-ad9e-33799f191a9c"
Intervals = "d8418881-c3e1-53bb-8760-2df7ec849ed5"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
ReinforcementLearning = "158674fc-8238-5cab-b5ba-03dfc80d1318"
StableRNGs = "860ef19b-820b-49d6-a774-d7a799459cd3"

[compat]
Flux = "~0.12.8"
Intervals = "~1.5.0"
Plots = "~1.25.2"
ReinforcementLearning = "~0.10.0"
StableRNGs = "~1.0.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "485ee0867925449198280d4af84bdb46a2a404d0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.0.1"

[[AbstractTrees]]
git-tree-sha1 = "03e0550477d86222521d254b741d470ba17ea0b5"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.3.4"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[ArrayInterface]]
deps = ["Compat", "IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "265b06e2b1f6a216e0e8f183d28e4d354eab3220"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.2.1"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[BFloat16s]]
deps = ["LinearAlgebra", "Printf", "Random", "Test"]
git-tree-sha1 = "a598ecb0d717092b5539dbbe890c98bac842b072"
uuid = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
version = "0.2.0"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[CUDA]]
deps = ["AbstractFFTs", "Adapt", "BFloat16s", "CEnum", "CompilerSupportLibraries_jll", "ExprTools", "GPUArrays", "GPUCompiler", "LLVM", "LazyArtifacts", "Libdl", "LinearAlgebra", "Logging", "Printf", "Random", "Random123", "RandomNumbers", "Reexport", "Requires", "SparseArrays", "SpecialFunctions", "TimerOutputs"]
git-tree-sha1 = "2c8329f16addffd09e6ca84c556e2185a4933c64"
uuid = "052768ef-5323-5732-b1bb-66c8b64840ba"
version = "3.5.0"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f2202b55d816427cd385a9a4f3ffb226bee80f99"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+0"

[[ChainRules]]
deps = ["ChainRulesCore", "Compat", "LinearAlgebra", "Random", "RealDot", "Statistics"]
git-tree-sha1 = "d9d08f88759465c7895db73d052c23e5c260f4a2"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.15.0"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "4c26b4e9e91ca528ea212927326ece5918a04b47"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.2"

[[ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "9a1d594397670492219635b35a3d830b04730d62"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.1"

[[CircularArrayBuffers]]
git-tree-sha1 = "ea7b08625ee7ad0304746c3dabafcd0929a451e3"
uuid = "9de3a189-e0c0-4e15-ba3b-b14b9fb0aec1"
version = "0.1.4"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[CommonRLInterface]]
deps = ["MacroTools"]
git-tree-sha1 = "21de56ebf28c262651e682f7fe614d44623dc087"
uuid = "d842c3ba-07a1-494f-bbec-f5741b0a3e98"
version = "0.3.1"

[[CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dce3e3fea680869eaa0b774b2e8343e9ff442313"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.40.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[DiffRules]]
deps = ["LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "d8f468c5cd4d94e86816603f7d18ece910b4aaf1"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.5.0"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "d6cc7abd52ebae5815fd75f6004a44abcf7a6b00"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.35"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[ElasticArrays]]
deps = ["Adapt"]
git-tree-sha1 = "a0fcc1bb3c9ceaf07e1d0529c9806ce94be6adf9"
uuid = "fdbdab4c-e67f-52f5-8c3f-e7b388dad3d4"
version = "1.2.9"

[[EllipsisNotation]]
deps = ["ArrayInterface"]
git-tree-sha1 = "3fe985505b4b667e1ae303c9ca64d181f09d5c05"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.1.3"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[ExprTools]]
git-tree-sha1 = "b7e3d17636b348f005f11040025ae8c6f645fe92"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.6"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "8756f9935b7ccc9064c6eef0bff0ad643df733a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.7"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Flux]]
deps = ["AbstractTrees", "Adapt", "ArrayInterface", "CUDA", "CodecZlib", "Colors", "DelimitedFiles", "Functors", "Juno", "LinearAlgebra", "MacroTools", "NNlib", "NNlibCUDA", "Pkg", "Printf", "Random", "Reexport", "SHA", "SparseArrays", "Statistics", "StatsBase", "Test", "ZipFile", "Zygote"]
git-tree-sha1 = "e8b37bb43c01eed0418821d1f9d20eca5ba6ab21"
uuid = "587475ba-b771-5e3f-ad9e-33799f191a9c"
version = "0.12.8"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "6406b5112809c08b1baa5703ad274e1dded0652f"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.23"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[Functors]]
git-tree-sha1 = "e4768c3b7f597d5a352afa09874d16e3c3f6ead2"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.2.7"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "0c603255764a1fa0b61752d2bec14cfbd18f7fe8"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+1"

[[GPUArrays]]
deps = ["Adapt", "LinearAlgebra", "Printf", "Random", "Serialization", "Statistics"]
git-tree-sha1 = "7772508f17f1d482fe0df72cabc5b55bec06bbe0"
uuid = "0c68f7d7-f131-5f86-a1c3-88cf8149b2d7"
version = "8.1.2"

[[GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "35898c2f2479b44cfed889edaf524e299797fe28"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "0.13.9"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "30f2b340c2fff8410d89bfcdc9c0a6dd661ac5f7"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.62.1"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fd75fa3a2080109a2c0ec9864a6e14c60cca3866"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.62.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "74ef6288d071f58033d54fd6708d4bc23a8b8972"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+1"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[IRTools]]
deps = ["InteractiveUtils", "MacroTools", "Test"]
git-tree-sha1 = "006127162a51f0effbdfaab5ac0c83f8eb7ea8f3"
uuid = "7869d1d1-7146-5819-86e3-90919afe41df"
version = "0.4.4"

[[IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "ca99cac337f8e0561c6a6edeeae5bf6966a78d21"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.1.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[IntervalSets]]
deps = ["Dates", "EllipsisNotation", "Statistics"]
git-tree-sha1 = "3cc368af3f110a767ac786560045dceddfc16758"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.5.3"

[[Intervals]]
deps = ["Dates", "Printf", "RecipesBase", "Serialization", "TimeZones"]
git-tree-sha1 = "323a38ed1952d30586d0fe03412cde9399d3618b"
uuid = "d8418881-c3e1-53bb-8760-2df7ec849ed5"
version = "1.5.0"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[Juno]]
deps = ["Base64", "Logging", "Media", "Profile"]
git-tree-sha1 = "07cb43290a840908a771552911a6274bc6c072c7"
uuid = "e5e0dc1b-0480-54bc-9374-aad01c23163d"
version = "0.8.4"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Printf", "Unicode"]
git-tree-sha1 = "7cc22e69995e2329cc047a879395b2b74647ab5f"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "4.7.0"

[[LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c5fc4bef251ecd37685bea1c4068a9cfa41e8b9a"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.13+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a8f4f279b6fa3c3c4f1adadd78a621b13a506bce"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.9"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "be9eef9f9d78cecb6f262f3c10da151a6c5ab827"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.5"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Media]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "75a54abd10709c01f1b86b84ec225d26e840ed58"
uuid = "e89f7d12-3494-54d1-8411-f7d8b9ae1f27"
version = "0.5.0"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "29714d0a7a8083bba8427a4fbfb00a540c681ce7"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.3"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NNlib]]
deps = ["Adapt", "ChainRulesCore", "Compat", "LinearAlgebra", "Pkg", "Requires", "Statistics"]
git-tree-sha1 = "2eb305b13eaed91d7da14269bf17ce6664bfee3d"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.7.31"

[[NNlibCUDA]]
deps = ["CUDA", "LinearAlgebra", "NNlib", "Random", "Statistics"]
git-tree-sha1 = "a2dc748c9f6615197b6b97c10bcce829830574c9"
uuid = "a00861dc-f156-4864-bf3c-e6376f28a68d"
version = "0.1.11"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "ee26b350276c51697c9c2d88a072b339f9f03d73"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.5"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "b084324b4af5a438cd63619fd006614b3b20b87b"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.15"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun"]
git-tree-sha1 = "65ebc27d8c00c84276f14aaf4ff63cbe12016c70"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.25.2"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "afadeba63d90ff223a6a48d2009434ecee2ec9e8"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.1"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Random123]]
deps = ["Libdl", "Random", "RandomNumbers"]
git-tree-sha1 = "0e8b146557ad1c6deb1367655e052276690e71a3"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.4.2"

[[RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

[[RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[ReinforcementLearning]]
deps = ["Reexport", "ReinforcementLearningBase", "ReinforcementLearningCore", "ReinforcementLearningEnvironments", "ReinforcementLearningZoo"]
git-tree-sha1 = "a3e8f3712ed6497c335a5334e97a817b5c35b19e"
uuid = "158674fc-8238-5cab-b5ba-03dfc80d1318"
version = "0.10.0"

[[ReinforcementLearningBase]]
deps = ["AbstractTrees", "CommonRLInterface", "Markdown", "Random", "Test"]
git-tree-sha1 = "1827f00111ea7731d632b8382031610dc98d8747"
uuid = "e575027e-6cd6-5018-9292-cdc6200d2b44"
version = "0.9.7"

[[ReinforcementLearningCore]]
deps = ["AbstractTrees", "Adapt", "ArrayInterface", "CUDA", "CircularArrayBuffers", "Compat", "Dates", "Distributions", "ElasticArrays", "FillArrays", "Flux", "Functors", "GPUArrays", "LinearAlgebra", "MacroTools", "Markdown", "ProgressMeter", "Random", "ReinforcementLearningBase", "Setfield", "Statistics", "StatsBase", "UnicodePlots", "Zygote"]
git-tree-sha1 = "04ea42a702ce60710a86b30b7c373f9c88b76348"
uuid = "de1b191a-4ae0-4afa-a27b-92d07f46b2d6"
version = "0.8.7"

[[ReinforcementLearningEnvironments]]
deps = ["DelimitedFiles", "IntervalSets", "LinearAlgebra", "MacroTools", "Markdown", "Pkg", "Random", "ReinforcementLearningBase", "Requires", "SparseArrays", "StatsBase"]
git-tree-sha1 = "e9a37b89d673b9e7e74269d2ec39eaeac8903096"
uuid = "25e41dd2-4622-11e9-1641-f1adca772921"
version = "0.6.11"

[[ReinforcementLearningZoo]]
deps = ["AbstractTrees", "CUDA", "CircularArrayBuffers", "DataStructures", "Dates", "Distributions", "Flux", "IntervalSets", "LinearAlgebra", "Logging", "MacroTools", "Random", "ReinforcementLearningBase", "ReinforcementLearningCore", "Setfield", "Statistics", "StatsBase", "StructArrays", "Zygote"]
git-tree-sha1 = "07622875fa0ed70e4091283c69d536ff027bae85"
uuid = "d607f57d-ee1e-4ba7-bcf2-7734c1e31854"
version = "0.5.6"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "0afd9e6c623e379f593da01f20590bacc26d1d14"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.8.1"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f0bccf98e16759818ffc5d97ac3ebf87eb950150"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.8.1"

[[StableRNGs]]
deps = ["Random", "Test"]
git-tree-sha1 = "3be7d49667040add7ee151fefaf1f8c04c8c8276"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.0"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "e7bc80dc93f50857a5d1e3c8121495852f407e6a"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.4.0"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "0f2aa8e32d511f758a2ce49208181f7733a0936a"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.1.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2bb0cb32026a66037360606510fca5984ccc6b75"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.13"

[[StatsFuns]]
deps = ["ChainRulesCore", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "bedb3e17cc1d94ce0e6e66d3afa47157978ba404"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.14"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "2ce41e0d042c60ecd131e9fb7154a3bfadbf50d3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.3"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "fed34d0e71b91734bf0a7e10eb1bb05296ddbcd0"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TimeZones]]
deps = ["Dates", "Downloads", "InlineStrings", "LazyArtifacts", "Mocking", "Printf", "RecipesBase", "Serialization", "Unicode"]
git-tree-sha1 = "ce5aab0b0146b81efefae52f13002e19c2af57ac"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.7.0"

[[TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "7cb456f358e8f9d102a8b25e8dfedf58fa5689bc"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.13"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[UnicodePlots]]
deps = ["Crayons", "Dates", "SparseArrays", "StatsBase"]
git-tree-sha1 = "78f9ced7f2db6d71db9857a3de26a0d7c5cc0853"
uuid = "b8865327-cd53-5732-bb35-84acbb429228"
version = "2.5.0"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "66d72dc6fcc86352f01676e8f0f698562e60510f"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.23.0+0"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[ZipFile]]
deps = ["Libdl", "Printf", "Zlib_jll"]
git-tree-sha1 = "3593e69e469d2111389a9bd06bac1f3d730ac6de"
uuid = "a5390f91-8eb1-5f08-bee0-b1d1ffed6cea"
version = "0.9.4"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[Zygote]]
deps = ["AbstractFFTs", "ChainRules", "ChainRulesCore", "DiffRules", "Distributed", "FillArrays", "ForwardDiff", "IRTools", "InteractiveUtils", "LinearAlgebra", "MacroTools", "NaNMath", "Random", "Requires", "SpecialFunctions", "Statistics", "ZygoteRules"]
git-tree-sha1 = "76475a5aa0be302c689fd319cd257cd1a512fb3c"
uuid = "e88e6eb3-aa80-5325-afca-941959d7151f"
version = "0.6.32"

[[ZygoteRules]]
deps = ["MacroTools"]
git-tree-sha1 = "8c1a8e4dfacb1fd631745552c8db35d0deb09ea0"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.2"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─25db9bdc-14cd-479e-bb18-573596c8efc6
# ╠═f206a273-a11f-41e5-a9b0-57f4851df198
# ╠═8a66a07b-6de0-441c-98cb-4863d3f08c01
# ╠═3212caa0-9354-44ac-a5d3-c71e11cf790d
# ╠═0d906b45-1c08-4b91-91b9-7353a3e81f2e
# ╠═f1741ee5-dbf9-4ec5-9bc0-fc4887e83ddc
# ╠═c664b43d-f3b6-4b23-b74e-fe40f7440d85
# ╟─60682e2f-b255-4475-94b2-f62f61de151a
# ╠═7de6ccf6-6083-4e7a-952d-b57117c70a29
# ╠═ef4c81e1-93db-4a18-ac7c-bb02f2e487af
# ╠═da5c5e6c-f262-47fa-a064-d5461053685d
# ╠═1ac26e69-4730-4814-b9ff-588131e56c09
# ╟─65396323-2f82-48dc-af49-7fa6e2467d87
# ╠═5a626901-e68c-466c-8dc5-b3a677a79d2a
# ╠═fa7eb71d-9bf8-497c-b68e-df16dc6b4165
# ╠═48a4d802-2457-43a3-b586-4db0b7495a74
# ╠═24d37839-8f0d-4574-8d88-38deb492dd3b
# ╟─e16cf8ad-e9d3-411a-b4ea-3d2db916c20f
# ╠═d03a3b60-5272-4b65-a78b-1bbabec89545
# ╠═6b5cbcac-9a0d-44d5-a808-7dec85f57a9f
# ╠═16ad2016-a30c-4ad8-9f1d-173970b9953d
# ╠═17336e5c-caff-4996-a942-be5fbde9a4a0
# ╠═83c232cf-b670-4939-8e7d-d8a40c4dd717
# ╠═69aeb998-8627-4d37-8c42-c46ec312fecc
# ╠═f1596f96-ac65-445d-a7a9-5a4f65f6950a
# ╠═a493439a-cb3e-4801-be9e-aa627aaa014e
# ╠═00c872a9-15a6-4f66-842d-c55cb516638c
# ╠═022cd200-912c-465f-8e3b-7c3d63710cfc
# ╠═352c85f4-7cfc-4d1e-b0e3-6ff9e0ce026a
# ╠═8ee77ce5-3883-4438-b243-3f00c3d34fdc
# ╠═21a19a63-7b1c-46be-b554-e919c9f6cb2d
# ╠═089e701e-72ec-48a0-b708-e231ddd443d0
# ╠═31c2a458-9911-4df3-a31f-3964b064e1da
# ╠═f0ffdde6-961c-4b0e-998e-bfb7c72c4765
# ╠═b142f6e1-204d-41df-b63e-45474077600d
# ╠═4fd96db9-744e-49a4-af11-ee2e192f1e7a
# ╟─5ea3e327-0b0f-4803-b7fc-3780773ee91d
# ╟─a13e7b99-0926-4725-a0d5-76640604c7b3
# ╠═1f1ff71a-8864-4d54-9bfe-c121cdcb13b3
# ╠═20e8c928-decf-44c1-884d-0dc393b102bd
# ╠═4efebd67-6cc4-44bc-a694-8b0fe32833a0
# ╠═de640be9-5d65-400a-ab7a-a058b52e3f77
# ╟─a409819b-6362-4090-a5f3-e53ed0611400
# ╟─242cc5fb-c0e0-4288-8628-b5618d532019
# ╠═ca9fa214-5bf3-4552-aed8-76d015e4ea37
# ╠═efb8321e-7fa9-412c-9944-f168ab181aef
# ╠═13f91d3d-7cca-4181-82f9-de0daa7c5a38
# ╟─8840ffef-75c5-4a72-b04e-6bf2010fc769
# ╟─b254d9ae-4433-4a77-a5dc-2f6bb14d4dce
# ╠═d89e225d-cbe6-43e9-b6e5-3ce72dcc4904
# ╠═0b8dcd2c-ad42-4af8-817f-227a16fc30ae
# ╠═1d568e15-6f9c-46b8-92b9-e8ab9c22a209
# ╠═9ba7873c-76b5-42f0-875e-5ea6131fccd1
# ╟─540f5bbf-24e1-4e35-8523-562e2f103276
# ╟─7cc6194e-53ae-4589-8f9b-c1de5ee3361e
# ╠═a78fbe62-f76b-43ff-a818-aa9f132a6bae
# ╠═a287598b-a57b-4a5a-9781-41458819f9a1
# ╠═da7e7ddb-30f5-4cc8-94db-573719a18cff
# ╟─d6dc4b56-7522-41ed-9d4d-9dfcf338c1ab
# ╟─81b701a5-35ad-44c2-ab5f-7c6e977ba2ed
# ╠═4b9fbfe2-670c-4f7c-8a75-2a790335b3a3
# ╠═f24feca5-eca6-4d0f-8554-49b202eafde9
# ╠═f504756f-1e09-4184-bb4b-9674e35d9167
# ╟─a3474b63-514a-4dd4-8c2b-b6a1521fa011
# ╟─6b990c1d-99d0-4dee-99fb-31cfa216f22f
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
