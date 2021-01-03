# Transactions Module

### `getTransaction`

`getTransaction` replies with the requested Transaction.

Arguments:
- `hash` (string)

The result is an object, as follows:
- `descendant` (string)

- `inputs` (array of objects, each as follows)
  - `hash` (string)

  	When (`descendant` == "Claim") or (`descendant` == "Send"):
    - `nonce` (int)

- `outputs` (array of objects, each as follows)
  - `amount` (string)

    When `descendant` == "Mint":
    - `key` (int): Miner nickname.

    When `descendant` == "Claim" or `descendant` == "Send":
    - `key` (string): Ed25519 Public Key.

- `hash` (string)

	When `descendant` == "Claim":
  - `signature` (string)

	When `descendant` == "Send":
  - `signature` (string)
  - `proof`     (int)
  - `argon`     (string)

	When `descendant` == "Data":
  - `data`      (string)
  - `signature` (string)
  - `proof`     (int)
  - `argon`     (string)

### `getUTXOs`

`getUTXOs` replies with an address's UTXOs (which are marked confirmed by the node and have no existing spenders).

Arguments:
- `address` (string)

The result is an array of objects, each as follows:
- `hash`  (string)
- `nonce` (int)

### `getBalance`

`getBalance` replies with the balance of the specified address, defined as the sum of the value of its UTXOs (using the same rules as above for which are considered).

Arguments:
- `address` (string)

The result is a string of the balance.

### `publishTransaction`

`publishTransaction` accepts a serialized Transaction, attempts to add it to the local Transactions DAG, and on success, broadcasts it to the network.

Arguments:
- `type`        (string): "Claim", "Send", or "Data".
- `transaction` (string): Serialized Transaction.

The result is a bool of if the transaction was successfully added. This will return true if the transaction is valid yet already exists, though it will NOT be broadcasted again in that case.
