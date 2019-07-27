# Merit Module

### `getHeight`

`getHeight` replies with the Blockchain's height. It takes in zero arguments and the result is an int of the height.

### `getDifficulty`

`getDifficulty` replies with the current difficulty. It takes in zero arguments and the result of a string of the difficulty.

### `getBlock`

`getBlock` replies with a Block. It takes in one argument.
- ID: Int of the nonce or string of the hash (int/string)

The result is an object, as follows:
- `hash`          (string)
- `header`        (object)
    - `nonce`     (int)
    - `last`      (string)
    - `aggregate` (string)
    - `miners`    (string)
    - `time`      (int)
    - `proof`     (int)
- `records` (array of objects, each as follows)
    - `holder` (string)
    - `nonce`  (int)
    - `merkle` (string)
- `miners` (array of objects, each as follows)
    - `miner`  (string)
    - `amount` (string)

### `getMerit`

`getMerit` replies with a Merit Holder's Merit. It takes in one argument.
- Merit Holder (string)

The result is an int of the Merit Holder's Merit.

### `getBlockTemplate`

`getBlockTemplate` replies with a template for mining a Block. It takes in zero arguments and replies with a string of the Block, without a proof.

Mining the Block occurs by hashing it with an 8-byte left padded nonce, despite the proof only being 4 bytes. Once mined, it can be published with the 4-byte proof appended to the template, via `merit_publishBlock` (see below).

### `publishBlock`

`publishBlock` adds the Block to the local Blockchain, and if it's valid, publishes it. It takes in one argument.
- Block (string)

The result is a bool of true.
