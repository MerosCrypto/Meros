# Personal Module

### `setMnemonic`

`setMnemonic` creates a new wallet using the passed in Mnemonic and password. This is irreversible and will delete the existing Wallet, having the node lose all access to the current Merit Holder and all funds.

Arguments:
- `mnemonic` (string; optional): Creates a new Mnemonic if omitted.
- `password` (string; optional): Defaults to "" if omitted, as according to the BIP 39 spec.

The result is a bool of true.

### `setParentPublicKey`

`setParentPublicKey` deletes the existing Wallet on the node, in an irreversible manner, losing all access to the current Merit Holder and all funds. It sets the Wallet to track the specified Parent Public Key, presumably one returned from `getParentPublicKey`. This will disable any operations requiring access to the private key, as well as all Merit Holder related operations. That said, this will preserve the functionality of address generation, `getTransactionTemplate`, and more, enabling Watch Wallet functionality.

Arguments:
- `account` (int; optional): Account this Public Key maps to. Defaults to 0.
- `key`     (string):        Parent Public Key.

The result is a bool of true.

### `getMnemonic`

`getMnemonic` replies with the Wallet's Mnemonic, without any password needed to use it. The result is a string of the Mnemonic.

### `getMeritHolderKey`

`getMeritHolderKey` replies with the BLS Private Key of the node's Merit Holder. The result is a string of the Private Key.

### `getMeritHolderNick`

`getMeritHolderKey` replies with the nickname of the node's Merit Holder. The result is an int of the nickname.

### `getParentPublicKey`

`getParentPublicKey` replies with the Parent Public Key for the specified account of the node's HD Wallet. If the account isn't known to the node, this method will create it.

Arguments:
- `account`  (int;    optional): Defaults to 0.
- `password` (string; optional): Only optional if the account was already created; defaults to "".

The result is a string of the specified Parent Public Key.

### `getAddress`

`getAddress` replies with a newly generated address. If the account used isn't known to the node, this method will create it.

Arguments:
- `account`  (int;    optional): Defaults to 0.
- `change`   (bool;   optional): Defaults to false.
- `index`    (int;    optional): Defaults to the first unused index. If an index above the hardened threshold is specified, hardened derivation is used. If the next unused index is used, and it's above the hardened threshold, this will error.
- `password` (string; optional): Only optional if the account was already created and a non-hardened index is specified; defaults to "".

The result is a string of the generated address.

### `send`

`send` creates and publishes a Send using the Wallet on the node.

Arguments:
- `account` (int; optional): The account to send from. Defaults to 0.
- `outputs` (array of objects)
  - `address` (string)
  - `amount`  (string)
- `password` (string; optional): Defaults to "".

The result is a string of the hash.

### `data`

`data` creates and publishes a Data using the Wallet on the node.

Arguments:
- `account`  (int; optional):    The account to send from. Defaults to 0.
- `hex`      (bool; optional):   Defaults to false. When true, data is treated as bytes, instead of as text.
- `data`     (string):           Must be at least 1 byte and at most 256 bytes.
- `password` (string; optional): Defaults to "".

The result is a string of the hash.

### `getUTXOs`

`getUTXOs` replies with every UTXO known to the specified account. If you only want the UTXOs for a specific address, use `transactions_getUTXOs`.

Arguments:
- `account` (int; optional): Defaults to 0.

The result is an array of objects, each as follows:
- `address` (string)
- `hash`    (string)
- `nonce`   (int)

### `getTransactionTemplate`

`getTransactionTemplate` replies with a signable transaction template usable by a program with the relevant private keys.

Arguments:
- `amount`      (string):                     Amount to send.
- `destination` (string):                     Address to send to.
- `account`     (int; optional):              Account to send from.
- `from`        (array of strings; optional): Addresses to use the UTXOs of.
- `change`      (string; optional):           Address to use as change.

This method will error if both `account` and `from` arguments are provided.

The result is an object, as follows:
- `type`: Type of the Transaction.

- `inputs` (array of objects, each as follows)
  - `hash`    (string)
  - `nonce`   (int)
  - `account` (int)
  - `change`  (bool)
  - `index`   (int)

- `outputs` (array of objects, each as follows)
  - `key`    (string)
  - `amount` (string)

- `publicKey`  (string): The public key this transaction will be checked against. Used to verify the correct private key is being used.
