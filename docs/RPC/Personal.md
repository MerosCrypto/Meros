# Personal Module

### `setMnemonic`

`setMnemonic` creates a new wallet using the passed in mnemonic and password. This is irreversible and will delete the existing wallet, having the node lose all access to the current Merit Holder and all funds.

Arguments:
- `mnemonic` (string): Optional; creates a new Mnemonic if omitted.
- `password` (string): Optional; defaults to "" if omitted, as according to the BIP 39 spec.

The result is a bool of true.

### `getMnemonic`

`getMnemonic` replies with the wallet's mnemonic, without its password. The result is a string of the mnemonic.

### `getMeritHolderKey`

`getMeritHolderKey` replies with the BLS Private Key of the node's Merit Holder. The result is a string of the Private Key.

### `getParentPublicKey`

`getParentPublicKey` replies with the Parent Public Key for the specified account of the node's HD Wallet, after applying BIP 44 purpose/coin type/account derivation. If the account isn't known to the node, this method will create it.

Arguments:
- `account`  (int):    Optional; defaults to 0.
- `password` (string): Optional if the account was already created; defaults to "".

The result is a string of the Parent Public Key.

### `getAddress`

`getAddress` replies with a newly generated address.

Arguments:
- `account`  (int):    Optional; defaults to 0; used in hardened derivation.
- `change`   (bool):   Optional; defaults to false.
- `index`    (int):    Optional; defaults to the first unused index. If an index above the hardened threshold is specified, hardened derivation is used. If the next unused index is used, and it's above the hardened threshold, this will error.
- `password` (string): Optional if the account was already created; defaults to "".

The result is a string of the generated address.

### `send`

`send` creates and publishes a Send using the Wallet on the node.

Arguments:
- `outputs` (array of objects)
  - `address` (string)
  - `amount`  (string)

The result is a string of the hash.

### `data`

`data` creates and publishes a Data using the Wallet on the node.

Arguments:
- `hex`  (bool):   Optional; defaults to false. When true, data is treated as bytes. Else, as text.
- `data` (string): Must be at least 1 byte and at most 256 bytes.

The result is a string of the hash.
