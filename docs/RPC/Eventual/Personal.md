# Personal Module

### `setMnemonic`
`setMnemonic` will create a new Wallet using the passed in Mnemonic and password, and set the Node's Wallet to it. It takes in two arguments, with one optional.
- Mnemonic (string)
- Password (string; optional)
It returns:
- `success` (bool)

### `getMnemonic`
`getMnemonic` will fetch and return the Node's Wallet's Mnemonic, without the password. It takes in zero arguments and returns:
- `mnemonic` (string)

### `getMasterPublicKey`
`getMasterPublicKey` will fetch and return the Master Public Key for the Node's HD Wallet, after applying BIP 44 derivation. It takes in zero arguments and returns:
- `masterPubKey` (string)

### `watchAddress`
`watchAddress` will enable Meros to use inputs from the specified address when creating Send Templates (see below). It takes one argument:
- `address` (string)

### `claim`
`claim` will create and publish a Claim using the Miner Wallet on the Node. It takes in two arguments:
- Mint Hashes (array of strings)
- Destination Address (string)
It returns:
- `hash` (string)

### `send`
`send` will create and publish a Send using the Wallet on the Node. It takes in a variable amount of objects, each as follows:
- Destination Address (string)
- Amount (string)
It returns:
- `hash` (string)

### `data`
`data` will create and publish a Data using the Wallet on the Node. It takes in one argument:
- Data (string)
It returns:
- `hash` (string)

### `getClaimTemplate`
`getClaimTemplate` will return a template for remotely signing a Claim. It takes in two arguments:
- Mint Hashes (array of strings)
- Destination Address (string)
It returns:
- `inputs` (array of strings)
- `claim` (string)
There will be one input per mint hash, each to be signed by the BLS Private Key of the BLS Public Key the Mint was meant for. Aggregating the signatures and appending the result to `claim` will make it publishable via `transactions_publishClaim`.

### `getSendTemplate`
`getSendTemplate` will return a template for remotely signing a Send. It takes in two arguments:
- Outputs (array of objects, each as follows):
    - `address` (string)
    - `amount` (string)
- Include Watch Only (bool; optional; defaults to true)
It returns:
- `send`  (string)
- `prefixedHash` (string)
The prefixed hash should be signed by the proper key. If every input was to the same address, the key is the normal Private Key. If the inputs were to multiple addresses, the key is a MuSig Private Key. Appending the signature, and then valid work, to `send` will make it publishable via `transactions_publishSend`.

### `getDataTemplate`
`getDataTemplate` will return a template for remotely signing a Data. It takes in two arguments:
- Sender (string)
- Data (string)
It returns:
- `data`  (string)
- `prefixedHash` (string)
The prefixed hash should be signed by the proper Private Key for the sender. Appending the signature, and then valid work, to `data` will make it publishable via `transactions_publishData`.
