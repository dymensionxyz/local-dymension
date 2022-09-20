# Contract Preparation
Setting up the dependencies for the CosmWasm smart contracts.

## Rust Installation
First, before installing Rust, you would need to install rustup.

On Mac/Linux systems, here are the commands for installing it:
```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

rustup default stable && rustup target list --installed && rustup target add wasm32-unknown-unknown
```

## Compile the Smart Contract
Compile the smart contract you want to deploy - for example we pull down the Nameservice smart contract:
```sh
git clone https://github.com/InterWasm/cw-contracts && cd cw-contracts && git checkout main && cd contracts/nameservice

rustup default stable && RUSTFLAGS='-C link-arg=-s' cargo wasm
```

## Optimized the Smart Contract
Optimize the compiled contract (as we want it to be as small as possible) by the following command:
```sh
# In the contract directory folder (in our example - `contracts/nameservice`)
docker run --rm -v "$(pwd)":/code \
  --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
  --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
  cosmwasm/rust-optimizer:0.12.6
```
This will compile the code inside `artifacts` directory:
```sh
export WASM_FILE=artifacts/cw_nameservice.wasm
```
