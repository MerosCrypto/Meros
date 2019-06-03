# Personal Module

### `setSecret`
`setSecret` will create a new HD Wallet using the passed in Secret, and set the Node's HD Wallet to it. It takes in one argument.
- Secret (string)
It returns:
- `success` (bool)

### `getWallet`
`getWallet` will fetch and return the HD Wallet on the Node, as if it was a regular Wallet. It takes in zero arguments and returns:
- `privateKey` (string)
- `publicKey`  (string)
- `address`    (string)

### `send`
`send` will create and publish a Send using the Wallet on the Node. It takes in three arguments:
- Destination Address (string)
- Amount (string)
- Nonce  (int)
It returns:
- `hash` (string)

### `receive`
`receive` will create and publish a Receive using the Wallet on the Node. It takes in three arguments:
- Input Address (string)
- Input Nonce   (string)
- Nonce         (int)
It returns:
- `hash` (string)

### `data`
`data` will create and publish a Data using the Wallet on the Node. It takes in two arguments:
- Data  (string)
- Nonce (int)
It returns:
- `hash` (string)
