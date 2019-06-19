# Transactions Module

### `getTransaction`
`getTransaction` will fetch and return a Transaction. It takes in one arguments:
- Hash (string)
It returns:
- `descendant` (string)

- `inputs` (array of objects, each as follows)
    - `hash` (string)
    When `descendant` == "Send":
        - `nonce` (int)

- `outputs` (array of objects, each as follows)
    - `amount` (string)
    When `descendant` == "Mint":
        - `key` (string; BLS Public Key)
    When `descendant` == "Claim" or `descendant` == "Send":
        - `key` (string; Ed25519 Public Key)

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
