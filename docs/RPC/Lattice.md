# Lattice Module

### `getHeight`
`getHeight` will fetch and return the amount of Entries on an Account. It takes in one argument:
- Address (string)
It returns a single field.
- `height` (string)

### `getBalance`
`getBalance` will fetch and return the balance of an Account. It takes in one argument:
- Address (string)
It returns a single field.
- `balance` (string)

### `getEntry`
`getEntry` will fetch and return an Entry. It takes in one argument:
- Hash (string)
It returns eight to ten fields, depending on the Entry type.
Every Entry:
- `descendant` (string)
- `sender` (string)
- `nonce` (int)
- `hash` (string)
- `signature` (string)
- `verified` (bool)

`descendant` == "Mint":
- `output` (string)
- `amount` (string)

`descendant` == "Claim":
- `mintNonce` (int)
- `bls` (string)

`descendant` == "Send":
- `output` (string)
- `amount` (string)
- `sha512` (string)
- `proof` (int)

`descendant` == "Receive":
- `index` (object)
    - `address` (string)
    - `nonce` (int)

`descendant` == "Data":
- `data` (string)
- `sha512` (string)
- `proof` (int)

### `getUnarchivedVerifications`
`getUnarchivedVerifications` will fetch and return all Unarchived Verifications on the Lattice. It takes in zero arguments and returns an array of Verification objects, each with three fields.
- `verifier` (string)
- `hash` (string)
- `signature` (string)
