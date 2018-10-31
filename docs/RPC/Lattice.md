# Lattice Module

### `send`
`send` will create and publish a Send using the Wallet on the Node. It takes in three arguments:
- Destination Address (string)
- Amount (string)
- Nonce (string)
It returns a single field.
- `hash` (string)

### `receive`
`receive` will create and publish a Receive using the Wallet on the Node. It takes in three arguments:
- Input Address (string)
- Input Nonce (string)
- Nonce (string)
It returns a single field.
- `hash` (string)

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
