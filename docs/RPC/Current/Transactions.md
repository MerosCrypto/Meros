# Transactions Module

### `getTransaction`

`getTransaction` replies with a Transaction. It takes in one argument:
- Hash (string)

The result is an object, as follows:
- `descendant` (string)

- `inputs` (array of objects, each as follows)
    - `hash` (string)

    	When `descendant` == "Send":
        - `nonce` (int)

- `outputs` (array of objects, each as follows)
    - `amount` (string)

        When `descendant` == "Mint":
        - `key` (string): BLS Public Key.

        When `descendant` == "Claim" or `descendant` == "Send":
        - `key` (string): Ed25519 Public Key.

- `hash`     (string)
- `verified` (bool)

	When `descendant` == "Mint":
    - `nonce` (int)

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

### `getMerit`

`getMerit` replies with how much Merit is behind the specified Transaction, as long as it is still in Epochs. It takes in one argument:
- Hash (string)

The result is an object, as follows:
- `merit`     (int)
