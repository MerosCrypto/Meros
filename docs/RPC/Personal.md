# Personal Module

### `getWallet`
`getWallet` will fetch and return the Wallet on the Node. It takes in zero arguments and returns:
- `seed` (string)
- `publicKey` (string)
- `address` (string)

### `setSeed`
`setSeed` will create a new Wallet using the passed in Seed, and set the Node's Wallet to it. It takes in one argument.
- Seed (string)
It returns:
- `success` (bool)

### `send`
`send` will create and publish a Send using the Wallet on the Node. It takes in three arguments:
- Destination Address (string)
- Amount (string)
- Nonce (string)
It returns:
- `hash` (string)

### `receive`
`receive` will create and publish a Receive using the Wallet on the Node. It takes in three arguments:
- Input Address (string)
- Input Nonce (string)
- Nonce (string)
It returns:
- `hash` (string)
