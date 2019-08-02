# Personal Module

### `setMnemonic`

`setMnemonic` creates a new Wallet using the passed in Mnemonic and password, and set the Node's Wallet to it. It takes in two arguments:
- Mnemonic (string): Optional; creates a new Mnemonic if omitted.
- Password (string): Optional; defaults to "" if omitted, as according to the BIP 39 spec.

The result is a bool of true.

### `getMnemonic`

`getMnemonic` replies with the Node's Wallet's Mnemonic, without the password. It takes in zero arguments and the result is a string of the mnemonic.

### `getAddress`

`getAddress` replies with an address. It takes in two arguments:
- Account (int):  Optional; defaults to 0; used in hardened derivation.
- Change  (bool): Optional; defaults to false.

The result is a string of the Wallet's address.

### `send`

`send` creates and publishes a Send using the Wallet on the Node. It takes in an array, with a variable length, of objects, each as follows:
- Destination Address (string)
- Amount              (string)

The result is a string of the hash.

### `data`

`data` creates and publishes a Data using the Wallet on the Node. It takes in one argument:
- Data (string)

The result is a string of the hash.

### `toAddress`

`toAddress` replies with the address for an Ed25519 Public Key. It takes in one argument:
- Public Key (string)

The result is a string of the address.
