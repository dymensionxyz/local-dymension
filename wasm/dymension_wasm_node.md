# Dymension-Wasm Node
Instructions for running locally dymension-wasm optimistic rollapp built using the RDK and dymint.

## Installation
Requires [Go version v1.18+](https://golang.org/doc/install).

```sh
git clone https://github.com/dymensionxyz/wasm.git --branch v0.1.1-alpha && cd wasm

go mod tidy && go mod download && make install
```

## Start node
Build, init and run the chain:
```sh
# Look at the script to check which parameters can be updated
export KEY_NAME=test-key 
export CHAIN_ID=test-chain

sh scripts/setup_and_run_node.sh
```
*For running the settlement layer without mock, check the [following instructions](../README.md)*


