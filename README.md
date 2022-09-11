# Local Dymension

Instructions for locally setup, building and running of dymension rollup.

## Set up work environment

Install go (version v1.18+): https://golang.org/doc/install.

Install docker: https://docs.docker.com/engine/install/

Install ignite: https://docs.ignite.com/guide/install

Install node: https://nodejs.org/en/download/

Install rust: https://www.rust-lang.org/tools/install

## Run dymension settlement

Clone the settlement repository:

```sh
git clone git@github.com:dymensionxyz/dymension.git && cd dymension
```

Build, init and run the chain:

```sh
# Look at the script to check which parameters can be updated
export CHAIN_ID="local-testnet"
export KEY_NAME="local-user"
export MONIKER_NAME="local"
export SETTLEMENT_RPC="0.0.0.0:36657"
export P2P_ADDRESS="0.0.0.0:36656"

./scripts/run_local.sh
```

## Setup and build dymension rollup

Scaffold chain:

```sh
ignite scaffold chain github.com/anonymous/checkers && cd checkers
```

Setting up rdk and dymint:

```sh
go mod edit -replace github.com/cosmos/cosmos-sdk=github.com/dymensionxyz/rdk@ffe24a21eca363c3b33266aaadda079c5f15d244
git config --global url.git@github.com:.insteadOf https://github.com/
export GOPRIVATE=github.com/dymensionxyz/*
go mod tidy && go mod download
ignite chain build
```

Build the checkers module by [this instructions](/checkers_rollup/build_module.md)

Init checkers-rollup chain:

```sh
export KEY_PLAYER_1="player1"
export KEY_PLAYER_2="player2"
export ROLLAP_ID="checkers"

checkersd tendermint unsafe-reset-all
checkersd init checkers-test --chain-id "$ROLLAP_ID"
checkersd keys add "$KEY_PLAYER_1"
checkersd keys add "$KEY_PLAYER_2"
checkersd add-genesis-account "$(checkersd keys show "$KEY_PLAYER_1" -a)" 100000000000stake
checkersd add-genesis-account "$(checkersd keys show "$KEY_PLAYER_2" -a)" 100000000000stake
checkersd gentx "$KEY_PLAYER_1" 100000000stake --chain-id "$ROLLAP_ID"
checkersd collect-gentxs
```

## Deploy dymension rollup

Create rollup entity in the dymension settlement

```sh
dymd tx rollapp create-rollapp "$ROLLAP_ID" stamp1 "genesis-path/1" 3 100 '{"Addresses":[]}' \
  --from "$KEY_NAME" \
  --chain-id "$CHAIN_ID" \
  --keyring-backend test
```

Initialize and attach a Sequencer:

```sh
export DESCRIPTION="{\"Moniker\":\"$MONIKER_NAME\",\"Identity\":\"\",\"Website\":\"\",\"SecurityContact\":\"\",\"Details\":\"\"}";
export CREATOR_ADDRESS="$(dymd keys show "$KEY_NAME" -a --keyring-backend test)"
export CREATOR_PUB_KEY="$(dymd keys show "$KEY_NAME" -p --keyring-backend test)"

dymd tx sequencer create-sequencer "$CREATOR_ADDRESS" "$CREATOR_PUB_KEY" "$ROLLAP_ID" "$DESCRIPTION" \
  --from "$KEY_NAME" \
  --chain-id "$CHAIN_ID" \
  --keyring-backend test
```

## Run dymension rollup

Run the checkers-rollup chain:

```sh
export SETTLEMENT_CONFIG="{\"node_address\": \"http:\/\/$SETTLEMENT_RPC\", \"rollapp_id\": \"$ROLLAP_ID\", \"dym_account_name\": \"$KEY_NAME\", \"keyring_home_dir\": \"$HOME/dymension/\", \"keyring_backend\":\"test\"}"
export NAMESPACE_ID=000000000000FFFF

checkersd start --dymint.aggregator true \
  --dymint.da_layer mock \
  --dymint.settlement_layer dymension \
  --dymint.settlement_config "$SETTLEMENT_CONFIG" \
  --dymint.block_batch_size 1000 \
  --dymint.namespace_id "$NAMESPACE_ID" \
  --dymint.block_time 1s
```

## Interact with rollup

Interact with the checkers rollup using the [following examples](/checkers_rollup/interaction.md)
