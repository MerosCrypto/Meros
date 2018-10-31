# Personal Module

### `getWallet`
`getWallet` will fetch and return the Wallet on the Node. It takes in zero arguments and returns three fields.
- `seed` (string)
- `publicKey` (string)
- `address` (string)

### `setSeed`
`setSeed` will create a new Wallet using the passed in Seed, and set the Node's Wallet to it. It takes in one argument.
- Seed (string)
It returns a single field.
- `success` (bool)
