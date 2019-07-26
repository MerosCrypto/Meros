# Transactions Module

### `getTransaction`

`getTransaction` replies with a Transaction. It takes in one argument:
- Hash (string)

The result is an object, as follows:
- `descendant` (string)

- `inputs` (array of objects, each as follows)
    - `hash` (string)

    	When `descendant` == "send":
        - `nonce` (int)

- `outputs` (array of objects, each as follows)
    - `amount` (string)

        When `descendant` == "mint":
        - `key` (string; BLS Public Key)

        When `descendant` == "claim" or `descendant` == "send":
        - `key` (string; Ed25519 Public Key)

- `hash`     (string)
- `verified` (bool)

	When `descendant` == "mint":
    - `nonce` (int)

	When `descendant` == "claim":
    - `signature` (string)

	When `descendant` == "send":
    - `signature` (string)
    - `proof`     (int)
    - `argon`     (string)

	When `descendant` == "data":
    - `data`      (string)
    - `signature` (string)
    - `proof`     (int)
    - `argon`     (string)

### `getWeight`

`getWeight` replies with the Merit behind a Transaction still in Epochs. It takes in one argument:
- Hash (string)

The result is an int of the weight.

### `getVerifiers`

`getVerifiers` replies with the Merit Holders who verified a Transaction still in Epochs. It takes in one argument:
- Hash (string)

The result is an array of strings, each a Merit Holder's BLS Public Key.

### `getUTXOs`

`getUTXOs` replies with the addresses' UTXOs. It takes in one argument:
- Address (string)

The result is an array of objects, each as follows:
- `hash` (string)
- `nonce` (int)

### `publishClaim`

`publishClaim` parses the serialized Claim, adds it to the local Transactions DAG, and if it's valid, publishes it. It takes in one argument.
- Claim (string).

The result is a bool of true.

### `publishSend`

`publishSend` parses the serialized Send, adds it to the local Transactions DAG, and if it's valid, publishes it. It takes in one argument.
- Send (string).

The result is a bool of true.

### `publishData`

`publishData` parses the serialized Data, adds it to the local Transactions DAG, and if it's valid, publishes it. It takes in one argument.
- Data (string).

The result is a bool of true.
