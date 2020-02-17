# Transactions Module

### `getTransaction`

`getTransaction` replies with a Transaction. It takes in one argument:
- Hash (string)

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

`getUTXOs` replies with the addresses' UTXOs. It takes in one argument:
- Address (string)

The result is an array of objects, each as follows:
- `hash`  (string)
- `nonce` (int)

### `getBalance`

`getBalance` replies with the balance of the specified Public Key. It takes in one argument:
- Hash (string)

The result is a string of the balance.

### `publishClaim`

`publishClaim` parses the serialized Claim, adds it to the local Transactions DAG, and if it's valid, publishes it. It takes in one argument.
- Claim (string)

The result is a bool of true.

### `publishSend`

`publishSend` parses the serialized Send, adds it to the local Transactions DAG, and if it's valid, publishes it. It takes in one argument.
- Send (string)

The result is a bool of true.

### `publishData`

`publishData` parses the serialized Data, adds it to the local Transactions DAG, and if it's valid, publishes it. It takes in one argument.
- Data (string)

The result is a bool of true.
