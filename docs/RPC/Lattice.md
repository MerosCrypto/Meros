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

### `getUnarchivedVerifications`
`getUnarchivedVerifications` will fetch and return all Unarchived Verifications on the Lattice. It takes in zero arguments and returns an array of Verification objects, each with three fields.
- `verifier` (string)
- `hash` (string)
- `signature` (string)
