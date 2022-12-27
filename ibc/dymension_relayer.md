# Dymension Relayer

Instructions for setup and run a relayer between dymint rollapp to other cosmos chain.

## Run dymension settlement

Build and run a dymension settlement node using [these instructions](/README.md#run-dymension-settlement)

## Build two chains with ibc module

For example, create two "planet" chains presented [here](/README.md#run-dymension-settlement)

* Follow only the scaffold and the source code modification sections.
* Don't use the Ignite configurations and the Ignite relaying.
* Create different dApps with different chains and different ports.
* In the rollap chain, make sure the `packet-timeout` take into account the settlement finalization time. (for the planet example, you
  can update the `packet-timeout-timestamp` flag when you run an ibc message).

Setting up the RDK and the dymension-IBC:

```sh
# For the rollap chain only
go mod edit -replace github.com/cosmos/cosmos-sdk=github.com/dymensionxyz/rdk@v0.1.2-alpha

# For both of the chains
go mod edit -replace github.com/cosmos/ibc-go/v3=github.com/dymensionxyz/ibc-go/v3@v3.0.0-rc2.0.20221221093207-06ff366809a8
go mod tidy && go mod download
ignite chain build
```

Init the chains

* Create genesis accounts and genesis transactions.
* Make sure the chains have different ports (especially the RPC urls).

## Register the rollapp on the dymension settlement layer

* Create rollapp entity in the dymension settlement.
* Initialize and attach a Sequencer to the rollapp.
* You can use [these instructions](/README.md#register-the-rollapp-on-the-dymension-settlement-layer) with the suitable properties.

## Run the chains

For running the rollapp chain, use [these instructions](/README.md#run-dymension-rollapp) with the suitable properties.

## Setup and run dymension relayer

Clone and build the dymension relayer:

```sh
git clone https://github.com/dymensionxyz/relayer.git && cd relayer && make install
```

Init the relayer with a settlement configuration:

```sh
export SETTLEMENT_RPC="0.0.0.0:26657"
export ROLLAPP_ID=rollapp-chain-id
export KEY_NAME="local-user"
export SETTLEMENT_CONFIG="{\"node_address\": \"http:\/\/$SETTLEMENT_RPC\", \"rollapp_id\": \"$ROLLAPP_ID\", \"dym_account_name\": \"$KEY_NAME\", \"keyring_home_dir\": \"$HOME/.dymension/\", \"keyring_backend\":\"test\"}"
rly config init --settlement-config "$SETTLEMENT_CONFIG"
```

Create for every chain a relayer-json file contains necessary details about the chain.

The file should contain a `client-type` property represents the type of the light-client will be created on the other chain. for rollapps
use `01-dymint` and for other cosmos chains use `07-tendermint`.

```sh
# planet-rollap.json
{
  "type": "cosmos",
  "value": {
    "key": "relayer-planet-key",
    "chain-id": "planet-chain",
    "rpc-addr": "http://0.0.0.0:46657",
    "account-prefix": "cosmos",
    "keyring-backend": "test",
    "gas-adjustment": 1.2,
    "gas-prices": "0.0000025stake",
    "debug": true,
    "timeout": "10s",
    "output-format": "json",
    "sign-mode": "direct",
    "client-type": "01-dymint"
  }
}
```

Configure the relayer with the chains.

```sh
export ROLLAPP_CHAIN_NAME=name1
export COSMOS_CHAIN_NAME=name2
export RELAYER_KEY_FOR_ROLLAP_CHAIN=relayer-key1
export RELAYER_KEY_FOR_COSMOS_CHAIN=relayer-key2
rly chains add --file /path/for/rollapp-chain-relayer.json "$ROLLAPP_CHAIN_NAME"
rly chains add --file /path/for/cosmos-chain-relayer.json "$COSMOS_CHAIN_NAME"
rly keys add "$ROLLAPP_CHAIN_NAME" "$RELAYER_KEY_FOR_ROLLAP_CHAIN"
rly keys add "$COSMOS_CHAIN_NAME" "$RELAYER_KEY_FOR_COSMOS_CHAIN"
```

Send tokens from the chains to the created relayer keys.

Create relayer-path between the chains:

```sh
export RELAYER_PATH=relayer-pathg-name
export IBC_PORT=ibc-port
export IBC_VERSION=ibc-version
rly paths new "$ROLLAPP_CHAIN_NAME" "$COSMOS_CHAIN_NAME" "$RELAYER_PATH" --src-port "$IBC_PORT" --dst-port "$IBC_PORT" --version "$IBC_VERSION"
```

Link between the chains:

```sh
rly transact link "$RELAYER_PATH" --src-port "$IBC_PORT" --dst-port "$IBC_PORT" --version "$IBC_VERSION"
```

Start relaying between the chains:

```sh
rly start "$RELAYER_PATH"
```

## Send IBC messages using the relayer

For example, if we use our planet example:

```sh
export IBC_PORT=ibc-port
export ROLLAPP_KEY=planet-key-name
export ROLLAPP_ID=rollapp-chain-id
export CHANNEL_NAME=channel-0
planet1d tx blog send-ibc-post "$IBC_PORT" "$CHANNEL_NAME" "Hello" "Hello Mars, I'm Alice from Earth" --from "$ROLLAPP_KEY" --chain-id "$ROLLAPP_ID"
```

Wait until the settlement finalization - you can query the dymension-settlement for the finalization height and compare it to the
transaction height.

Check the message received:
```sh
planet2d query blog list-post
```
