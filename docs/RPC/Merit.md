# Merit Module

### `getHeight`
`getHeight` will fetch and return the Blockchain's height. It takes in zero arguments and returns:
- `height` (int)

### `getDifficulty`
`getDifficulty` will fetch and return the Block's difficulty. It takes in zero arguments and returns:
- `difficulty` (string)

### `getBlock`
`getBlock` will fetch and return a Block. It takes in one argument.
- Nonce (int)
It returns:
- `header`        (object)
    - `nonce`         (int)
    - `last`          (string)
    - `verifications` (string)
    - `miners`        (string)
    - `time`          (int)
    - `proof`         (int)
- `hash`          (string)
- `verifications` (array of objects, each as follows)
    - `verifier`      (string)
    - `nonce`         (int)
- `miners`        (array of objects, each as follows)
    - `miner`         (string)
    - `amount`        (string)

### `publishBlock`
`publishBlock` will add the Block to the local Blockchain, and if it's valid, publish it. It takes in one argument.
- Block (string).
