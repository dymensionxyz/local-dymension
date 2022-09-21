# Dymension-Ethermint Node

Instructions for running locally dymension-ethermint optimistic rollapp built using the RDK and dymint.

## Installation

Requires [Go version v1.18+](https://golang.org/doc/install).

```sh
git clone git@github.com:dymensionxyz/ethermint.git && cd ethermint

git config --global url.git@github.com:.insteadOf https://github.com/

export GOPRIVATE=github.com/dymensionxyz/*

go mod tidy && go mod download && make install
```

## Start node

Build, init and run the chain:

```sh
sh init.sh
```

*For running the settlement layer without mock, check the [following instructions](../README.md)*

## Create and test an example contract

Create truffle contract by following [these instructions](./truffle_contract_preparation.md)

Deploy the contract:

```shc
truffle migrate --network development
```

Run the Truffle tests using the dymension-ethermint node:

```sh
truffle test --network development
```
At the end, you should see the following success message:
```sh
Using network 'development'.


Compiling your contracts...
===========================
> Everything is up to date, there is nothing to compile.


  Contract: Counter
    ✔ should add (1026ms)


  1 passing (2s)
```
