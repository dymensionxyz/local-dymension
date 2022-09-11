# Interact with the dymension-checkers chain
Fetch the accounts addresses
```sh
export player1=$(checkersd keys show player1 -a)
export player2=$(checkersd keys show player2 -a)
```
Show the id of the next game that will be created:
```sh
checkersd query checkers show-next-game

# NextGame:
#   fifoHead: "-1"
#   fifoTail: "-1"
#   idValue: "1"
```
Create new game
```sh
checkersd tx checkers create-game $player1 $player2 1000000 --from $player1 --gas auto
```
Confirm wager
```sh
checkersd query bank balances $player2

# balances:
# - amount: "99999000000" # <- 1,000,000 fewer
#   denom: stake
```
Show the created game (with the id that received before)
```sh
checkersd query checkers show-stored-game 1

# storedGame:
#   afterId: "-1"
#   beforeId: "-1"
#   black: cosmos1g7vc6dvmf6ezzyj35yn9l3d5ezecrhe2yx2ak3
#   deadline: 2022-09-06 12:28:19.50797 +0000 UTC
#   game: '*b*b*b*b|b*b*b*b*|*b*b*b*b|********|********|r*r*r*r*|*r*r*r*r|r*r*r*r*'
#   index: "1"
#   moveCount: "0"
#   red: cosmos17x
#   turn: b
#   wager: "1000000"
#   winner: '*'
```
For showing just the board in nice square view:
```sh
checkersd query checkers show-stored-game 1 --output json | jq ".storedGame.game" | sed 's/"//g' | sed 's/|/\n/g'

# *b*b*b*b
# b*b*b*b*
# *b*b*b*b
# ********
# ********
# r*r*r*r*
# *r*r*r*r
# r*r*r*r*
```
Play the first move
```sh
checkersd tx checkers play-move 1 1 2 2 3 --from $player2
checkersd query checkers show-stored-game 1 --output json | jq ".storedGame.game" | sed 's/"//g' | sed 's/|/\n/g'

# *b*b*b*b
# b*b*b*b*
# ***b*b*b
# **b*****
# ********
# r*r*r*r*
# *r*r*r*r
# r*r*r*r*
```
Reject the game
```sh
checkersd tx checkers reject-game 1 --from $player1
checkersd query checkers list-stored-game

# pagination:
#   next_key: null
#   total: "0"
# storedGame: []
```
Confirm wager returned
```sh
checkersd query bank balances $player2

# balances:
# - amount: "100000000000" # <- 1,000,000 are back
#   denom: stake
```
Simulate winning
```sh
checkersd tx checkers create-game $player1 $player2 1000000 --from $player1 --gas auto
checkersd tx checkers play-move 2 1 2 2 3 --from $player2
checkersd tx checkers play-move 2 0 5 1 4 --from $player1
```
Wait 5 minutes for game expiration (you can also actually win the game but it hard without ui-client)
```sh
checkersd query checkers show-stored-game 2

# We can se at the bottom that the red player (that made the last move) was win.

# storedGame:
# - afterId: "-1"
#   beforeId: "-1"
#   black: cosmos1erdhtzmmmfafuu77eus5wqceag4rkwcl8qy9x4
#   deadline: 2022-09-06 13:10:47.05588 +0000 UTC
#   game: '*b*b*b*b|b*b*b*b*|***b*b*b|**b*****|*r******|**r*r*r*|*r*r*r*r|r*r*r*r*'
#   index: "1"
#   moveCount: "2"
#   red: cosmos1a84u9zfyyghd0ks4tssuu4s656y5z77p06ad2p
#   turn: b
#   wager: "1000000"
#   winner: r
```
Confirm that both player1 and player2 paid their wagers
```sh
checkersd query bank balances $player1
checkersd query bank balances $player2

# balances:
# - amount: "99901000000" # <- 1,000,000 more than at the beginning
#   denom: stake

# balances:
# - amount: "99999000000" # <- 1,000,000 are gone for good
#   denom: stake
```
