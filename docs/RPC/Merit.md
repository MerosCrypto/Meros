# Merit Module

### `getHeight`
`getHeight` will fetch and return the Blockchain's height. It takes in zero arguments and returns:
- `height` (int)

### `getDifficulty`
`getDifficulty` will fetch and return the current difficulty. It takes in zero arguments and returns:
- `difficulty` (string)

### `getBlock`
`getBlock` will fetch and return a Block. It takes in one argument.
- Nonce (int)
It returns:
- `header`        (object)
    - `nonce`     (int)
    - `last`      (string)
    - `aggregate` (string)
    - `miners`    (string)
    - `time`      (int)
    - `proof`     (int)
- `hash`          (string)
- `records` (array of objects, each as follows)
    - `holder` (string)
    - `nonce`  (int)
    - `merkle` (string)
- `miners` (array of objects, each as follows)
    - `miner`  (string)
    - `amount` (string)

### `publishBlock`
`publishBlock` will add the Block to the local Blockchain, and if it's valid, publish it. It takes in one argument.
- Block (string).
