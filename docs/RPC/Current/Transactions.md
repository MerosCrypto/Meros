# Transactions Module

### `getTransaction`

`getTransaction` will fetch and return a Transaction. It takes in one arguments:
- Hash (string)

It returns:
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
