# Connect your Keplr wallet with Wasm.

Instructions for adding the dymension-wasm network to the keplr and sync an account.

## Init and start node

Init and start dymension-wasm node by following [these instructions](./dymension_wasm_node.md)

## Adding a New Network

Make sure you have Keplr extension installed in your browser.

Enter to the wasm folder, then install a tool that allows you to add new local networks to the keplr wallet.

```sh
cd keplr && npm install && npm run dev
```

Use the tool to add the dymension-wasm network:

1. Browse to [link to the tool](http://localhost:8081/).
2. Update the fields according to the running dymension-wasm node. in case you run the wasm node without changing the
   default values, you don't need to update any of the tool fields. after that.
3. click `Submit`.
4. In the Keplr wallet extension, click on `Approve`.
5. Open the Keplr extension and change the network (selector in the top) to the chain-name you choose in the tool (by
   default is: `Dymension-wasm`).

## Send tokens to the Keplr account

Copy the account address (by clicking on the address at the top) - make sure you have as account in the Keplr extension.

```sh
ACCOUNT_ADDRESS=<keplr-account-address>
```

Run send transaction from the dymension-wasm account to the Keplr account:

```sh
KEY_NAME=test-key 

wasmd tx bank send $(wasmd keys show $KEY_NAME -a) $ACCOUNT_ADDRESS 1000000000uwasm
```

Your account balance should show up as 1000 WASM (if not, try refresh the wallet or change and return the network).

