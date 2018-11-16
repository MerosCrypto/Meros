# Lattice Module

### `getHeight`
`getHeight` will fetch and return the amount of Entries on an Account. It takes in one argument:
- Address (string)
It returns:
- `height` (string)

### `getBalance`
`getBalance` will fetch and return the balance of an Account. It takes in one argument:
- Address (string)
It returns:
- `balance` (string)

### `getEntryByHash`
`getEntryByHash` will fetch and return an Entry. It takes in one argument:
- Hash (string)
It returns:
    For every entry:
    - `descendant` (string)
    - `sender` (string)
    - `nonce` (int)
    - `hash` (string)
    - `signature` (string)
    - `verified` (bool)

    When `descendant` == "Mint":
        - `output` (string)
        - `amount` (string)

    When `descendant` == "Claim":
        - `mintNonce` (int)
        - `bls` (string)

    When `descendant` == "Send":
        - `output` (string)
        - `amount` (string)
        - `sha512` (string)
        - `proof` (int)

    When `descendant` == "Receive":
        - `index` (object)
            - `address` (string)
            - `nonce` (int)

    When `descendant` == "Data":
        - `data` (string)
        - `sha512` (string)
        - `proof` (int)

### `getEntryByIndex`
`getEntryByIndex` will fetch and return an Entry. It takes in two arguments:
- Address (string)
- nonce (int)
It returns:
    For every entry:
    - `descendant` (string)
    - `sender` (string)
    - `nonce` (int)
    - `hash` (string)
    - `signature` (string)
    - `verified` (bool)

    When `descendant` == "Mint":
        - `output` (string)
        - `amount` (string)

    When `descendant` == "Claim":
        - `mintNonce` (int)
        - `bls` (string)

    When `descendant` == "Send":
        - `output` (string)
        - `amount` (string)
        - `sha512` (string)
        - `proof` (int)

    When `descendant` == "Receive":
        - `index` (object)
            - `address` (string)
            - `nonce` (int)

    When `descendant` == "Data":
        - `data` (string)
        - `sha512` (string)
        - `proof` (int)

### `getUnarchivedVerifications`
`getUnarchivedVerifications` will fetch and return all Unarchived Verifications on the Lattice. It takes in zero arguments and returns an array of objects, each as follows:
- `verifier` (string)
- `hash` (string)
- `signature` (string)
