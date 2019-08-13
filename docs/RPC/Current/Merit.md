# Merit Module

### `getHeight`

`getHeight` replies with the Blockchain's height. It takes in zero arguments and the result is an int of the height.

### `getDifficulty`

`getDifficulty` replies with the current difficulty. It takes in zero arguments and the result of a string of the difficulty.

### `getBlock`

`getBlock` replies with a Block. It takes in one argument.
- ID (int/string): Either the nonce as an int or hash as a string.

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

### `getTotalMerit`

`getTotalMerit` replies with the total amount of Merit in existence. It takes in zero arguments and the result is an int of the total amount of Merit.

### `getLiveMerit`

`getLiveMerit` replies with the amount of live Merit in existence. It takes in zero arguments and the result is an int of the amount of live Merit.

### `getMerit`

`getMerit` replies with a Merit Holder's Merit. It takes in one argument.
- Merit Holder (string)

The result is an object, as follows:
- `live`      (bool)
- `malicious` (bool)
- `merit`     (int)

### `getBlockTemplate`

`getBlockTemplate` replies with a template for mining a Block. It takes in an array, with a variable length, of objects, each as follows:
- `miner`  (string): BLS Public Key of the Miner.
- `amount` (int):    Amount of Merit to give this miner.

The amount of Merit given to every miner must equal 100.

The result is an object, as follows:
- `header` (string)
- `body`   (string)

Mining the Block occurs by hashing the header with an 8-byte left padded proof, despite the proof only being 4 bytes. Once mined, it can be published by appending the 4-byte proof to the header, appending the body to the completed header, and then calling `merit_publishBlock` (see below).

### `publishBlock`

`publishBlock` adds the Block to the local Blockchain, and if it's valid, publishes it. It takes in one argument.
- Block (string)

The result is a bool of true.
