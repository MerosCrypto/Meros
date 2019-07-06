# Personal Module

### `setSeed`
`setSeed` will create a new HD Wallet using the passed in Seed, and set the Node's HD Wallet to it. It takes in one argument.
- Seed (string)
It returns:
- `success` (bool)

### `getWallet`
`getWallet` will fetch and return the HD Wallet on the Node, as if it was a regular Wallet. It takes in zero arguments and returns:
- `seed` (string)
- `address`    (string)

### `send`
`send` will create and publish a Send using the Wallet on the Node. It takes in two arguments:
- Destination Address (string)
- Amount (string)
It returns:
- `hash` (string)

### `data`
`data` will create and publish a Send using the Wallet on the Node. It takes in one argument:
- Data (string)
It returns:
- `hash` (string)
