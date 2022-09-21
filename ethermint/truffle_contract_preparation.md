# Truffle Contract Preparation

Instructions for create, init and compile a truffle project.

## Install dependencies

First, install the latest Truffle version on your machine globally:

```sh
yarn global add truffle
```

## Create Truffle Project

Create a new directory to host the contracts and initialize it:

```sh
mkdir ethermint-truffle && cd ethermint-truffle
truffle init
```

Create `contracts/Counter.sol` containing the following contract:

```js
contract Counter {
  uint256 counter = 0;

  function add() public {
    counter++;
  }

  function subtract() public {
    counter--;
  }

  function getCounter() public view returns (uint256) {
    return counter;
  }
}
```

Create `test/counter_test.js` containing the following tests:

```js
const Counter = artifacts.require("Counter")

contract('Counter', accounts => {
  const from = accounts[0]
  let counter

  before(async() => {
    counter = await Counter.new()
  })

  it('should add', async() => {
    await counter.add()
    let count = await counter.getCounter()
    assert(count == 1, `count was ${count}`)
  })
})
```
Open truffle-config.js and uncomment the development section in networks:

```js
development: {
    host: "127.0.0.1",     // Localhost (default: none)
    port: 8545,            // Standard Ethereum port (default: none)
    network_id: "*",       // Any network (default: none)
},
```
Compile the contract:
```sh
truffle compile
```
