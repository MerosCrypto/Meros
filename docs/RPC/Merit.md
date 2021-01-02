# Merit Module

### `getHeight`

`getHeight` replies with the Blockchain's height. The result is an int of the height.

### `getDifficulty`

`getDifficulty` replies with the current difficulty. This should NOT be used by miners, as the difficulty is multiplied for new miners. `getBlockTemplate` is guaranteed to return the difficulty that a Block would be checked against. The result is an int of the difficulty.

### `getBlock`

`getBlock` replies with the requested Block.

Arguments:
- `id` (int/string): Either the nonce or hash.

The result is an object, as follows:
- `hash`   (string)
- `header` (object)
  - `version`     (int)
  - `last`        (string)
  - `contents`    (string)
  - `sketchSalt`  (string)
  - `sketchCheck` (string)
  - `miner`       (int/string): Either the miner's nick as an int or the key as a string if this is their first Block.
  - `time`        (int)
  - `proof`       (int)
  - `signature`   (string)

- `transactions` (array of objects, each as follows)
  - `hash`    (string)
  - `holders` (array of ints)

- `elements` (array of objects, each as follows)
  - `descendant` (string)
  - `holder`     (int)

    When `descendant` == "SendDifficulty":
    - `nonce`      (int)
    - `difficulty` (int)

    When `descendant` == "DataDifficulty":
    - `nonce`      (int)
    - `difficulty` (int)

- `removals` (array of ints): Whoever got their Merit removed by this Block.

- `aggregate` (string)

### `getNickname`

`getNickname` replies with a Merit Holder's nickname.

Arguments:
- `key` (string): Merit Holder's BLS Public Key.

The result is an int of the nickname.

### `getPublicKey`

`getPublicKey` replies with the specified Merit Holder's BLS Public Key.

Arguments:
- `nick` (int)

The result is an string of the BLS Public Key.

### `getTotalMerit`

`getTotalMerit` replies with the total amount of Merit in existence. The result is an int of the total amount of Merit.

### `getUnlockedMerit`

`getUnlockedMerit` replies with the amount of Unlocked Merit in existence. The result is an int of the amount of Unlocked Merit.

### `getMerit`

`getMerit` replies with the specified Merit Holder's Merit.

Arguments:
- `nick` (int)

The result is an object, as follows:
- `status`    (string): "Unlocked", "Locked", or "Pending".
- `malicious` (bool):   Whether or not this holder has a Merit Removal against them pending.
- `merit`     (int)

### `getBlockTemplate`

`getBlockTemplate` replies with a template for mining a Block.

Arguments:
- `miner` (string): BLS Public Key of the Miner.

The result is an object, as follows:
- `id`         (int):    The template ID.
- `key`        (string): The RandomX cache key.
- `header`     (string)
- `difficulty` (int)

Mining the Block occurs by hashing the header with a 4-byte proof appended. After the initial hash, the hash is signed by the miner, and the hash is hashed with the signature appended. If it beats the difficulty, it can be published by appending the 4-byte proof to the header, then appending the signature to the header, and then calling `merit_publishBlock` with the ID (see below).

### `publishBlock`

`publishBlock` adds a Block to the local Blockchain, and if it's valid, publishes it.

Arguments:
- `id`    (int):    ID of the template used.
- `block` (string): The serialized BlockHeader.

The result is a bool of true.
