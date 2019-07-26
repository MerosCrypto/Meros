# Personal Module

### `setMnemonic`

`setMnemonic` creates a new Wallet using the passed in Mnemonic and password, and set the Node's Wallet to it. It takes in two arguments, with both optional.
- Mnemonic (string; optional; creates a new Mnemonic if omitted)
- Password (string; optional; defaults to "", according to the BIP39 spec)

The result is a bool of true.

### `getMnemonic`

`getMnemonic` replies with the Node's Wallet's Mnemonic, without the password. It takes in zero arguments and the result is a string of the mnemonic.

### `getParentPublicKey`

`getParentPublicKey` replies with the Parent Public Key for the Node's HD Wallet, after applying BIP 44 derivation. It takes in zero arguments and the result is a string of the Parent Public Key.

The result is a bool of true.

### `getWatchedAddresses`

`getWatchedAddresses` replies with every watched address. It takes in zero arguments and the result is an array of strings, each a watched address.

### `watchAddress`

`watchAddress` instructs Meros to use inputs from the specified address when creating Send Templates (see below). It takes one argument:
- `address` (string)

The result is a bool of true.

### `unwatchAddress`

`watchAddress` instructs Meros to no longer watch an address. It takes one argument:
- `address` (string)

The result is a bool of true.

### `claim`

`claim` creates and publishes a Claim using the Miner Wallet on the Node. It takes in two arguments:
- Mint Hashes (array of strings)
- Destination Address (string)

The result is a string of the hash.

### `send`

`send` creates and publishes a Send using the Wallet on the Node. It takes in an array, with a variable length, of objects, each as follows:
- Destination Address (string)
- Amount (string)

The result is a string of the hash.

### `data`

`data` creates and publishes a Data using the Wallet on the Node. It takes in one argument:
- Data (string)

The result is a string of the hash.

### `getClaimTemplate`

`getClaimTemplate` replies with a template for remotely signing a Claim. It takes in two arguments:
- Mint Hashes (array of strings)
- Destination Address (string)

The result is an object, as follows:
- `inputs` (array of strings)
- `claim` (string)

There will be one input per mint hash, each to be signed by the BLS Private Key of the BLS Public Key the Mint was meant for. Aggregating the signatures and appending the result to `claim` will make it publishable via `transactions_publishClaim`.

### `getSendTemplate`

`getSendTemplate` replies with a template for remotely signing a Send. It takes in two arguments:
- Outputs (array of objects, each as follows):
    - `address` (string)
    - `amount` (string)
- Include Watch Only (bool; optional; defaults to true)

The result is an object, as follows:
- `send`  (string)
- `prefixedHash` (string)

The prefixed hash should be signed by the proper key. If every input was to the same address, the key is the normal Private Key. If the inputs were to multiple addresses, the key is a MuSig Private Key. Appending the signature, and then valid work, to `send` will make it publishable via `transactions_publishSend`.

### `getDataTemplate`

`getDataTemplate` replies with a template for remotely signing a Data. It takes in two arguments:
- Sender (string)
- Data (string)

The result is an object, as follows:
- `data`  (string)
- `prefixedHash` (string)

The prefixed hash should be signed by the proper Private Key for the sender. Appending the signature, and then valid work, to `data` will make it publishable via `transactions_publishData`.
