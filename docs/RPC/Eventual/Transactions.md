# Transactions Module

### `getTransaction`

`getTransaction` fetches and return a Transaction. It takes in one argument:
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

### `getUTXOs`

`getUTXOs` fecthes and replies with the addresses' UTXOs. It takes in one argument:
- Address (string)

The result is an array of objects, each as follows:
- `hash` (string)
- `nonce` (int)

### `getWeight`

`getWeight` fetches and replies with the Merit behind a Transaction. It takes in one argument:
- Hash (string)

The result is an int of the weight.

### `publishClaim`

`publishClaim` parses the serialized Claim, add it to the local Transactions DAG, and if it's valid, publish it. It takes in one argument.
- Claim (string).

The result is a bool of true.

### `publishSend`

`publishSend` parses the serialized Send, add it to the local Transactions DAG, and if it's valid, publish it. It takes in one argument.
- Send (string).

The result is a bool of true.

### `publishData`

`publishData` parses the serialized Data, add it to the local Transactions DAG, and if it's valid, publish it. It takes in one argument.
- Data (string).

The result is a bool of true.
