# Local Dymension

Instructions for locally setup, building and running of dymension rollapp.

## Set up work environment

Install go (version v1.18): https://golang.org/doc/install.

Install ignite: https://docs.ignite.com/guide/install

## Run dymension settlement

Clone the dymension settlement repository:

```sh
git clone https://github.com/dymensionxyz/dymension.git --branch v0.1.0-alpha && cd dymension
```

Build and init the chain:

```sh
export CHAIN_ID="local-testnet"
export KEY_NAME="local-user"
export MONIKER_NAME="local"
export SETTLEMENT_RPC="0.0.0.0:36657"
export GRPC_ADDRESS="0.0.0.0:8090"
export GRPC_WEB_ADDRESS="0.0.0.0:8091"
export P2P_ADDRESS="0.0.0.0:36656"

sh scripts/setup_local.sh
```

Run the chain:

```sh
sh scripts/run_local.sh
```

## Setup and build dymension rollapp

Build the chain:

```sh
git clone https://github.com/dymensionxyz/local-dymension.git && cd local-dymension

export WORKSPACE_PATH=$HOME/workspace

cd checkers/build_chain_script && sh build.sh
```

Or build it manually using [these instructions](/checkers/build_chain.md)

Setting up the RDK:

```sh
cd "$WORKSPACE_PATH/checkers"
go mod edit -replace github.com/cosmos/cosmos-sdk=github.com/dymensionxyz/rdk@v0.1.0-sdk-v0.45.8-dymint-v0.1.0-alpha
go mod tidy && go mod download
ignite chain build
```

Init checkers-rollapp chain:

```sh
KEY_PLAYER_1="player1"
KEY_PLAYER_2="player2"
ROLLAPP_ID="checkers"

checkersd tendermint unsafe-reset-all
checkersd init checkers-test --chain-id "$ROLLAPP_ID"
checkersd keys add "$KEY_PLAYER_1"
checkersd keys add "$KEY_PLAYER_2"
checkersd add-genesis-account "$(checkersd keys show "$KEY_PLAYER_1" -a)" 100000000000stake
checkersd add-genesis-account "$(checkersd keys show "$KEY_PLAYER_2" -a)" 100000000000stake
checkersd gentx "$KEY_PLAYER_1" 100000000stake --chain-id "$ROLLAPP_ID"
checkersd collect-gentxs
```

## Register the rollapp on the dymension settlement layer

Create rollapp entity in the dymension settlement

```sh
CHAIN_ID="local-testnet"
KEY_NAME="local-user"

dymd tx rollapp create-rollapp "$ROLLAPP_ID" stamp1 "genesis-path/1" 3 100 '{"Addresses":[]}' \
  --from "$KEY_NAME" \
  --chain-id "$CHAIN_ID" \
  --keyring-backend test
```

Initialize and attach a Sequencer to the rollapp:

```sh
MONIKER_NAME="local"
DESCRIPTION="{\"Moniker\":\"$MONIKER_NAME\",\"Identity\":\"\",\"Website\":\"\",\"SecurityContact\":\"\",\"Details\":\"\"}";
CREATOR_ADDRESS="$(dymd keys show "$KEY_NAME" -a --keyring-backend test)"
CREATOR_PUB_KEY="$(dymd keys show "$KEY_NAME" -p --keyring-backend test)"

dymd tx sequencer create-sequencer "$CREATOR_ADDRESS" "$CREATOR_PUB_KEY" "$ROLLAPP_ID" "$DESCRIPTION" \
  --from "$KEY_NAME" \
  --chain-id "$CHAIN_ID" \
  --keyring-backend test
```

## Run dymension rollapp

Run the checkers-rollapp chain:

```sh
SETTLEMENT_RPC="0.0.0.0:36657"
SETTLEMENT_CONFIG="{\"node_address\": \"http:\/\/$SETTLEMENT_RPC\", \"rollapp_id\": \"$ROLLAPP_ID\", \"dym_account_name\": \"$KEY_NAME\", \"keyring_home_dir\": \"$HOME/.dymension/\", \"keyring_backend\":\"test\"}"
NAMESPACE_ID=000000000000FFFF

checkersd start --dymint.aggregator true \
  --dymint.da_layer mock \
  --dymint.settlement_layer dymension \
  --dymint.settlement_config "$SETTLEMENT_CONFIG" \
  --dymint.block_batch_size 500 \
  --dymint.namespace_id "$NAMESPACE_ID" \
  --dymint.block_time 0.2s
```

## Interact with rollapp

Interact with the checkers rollapp using the [following examples](/checkers/interaction.md)
