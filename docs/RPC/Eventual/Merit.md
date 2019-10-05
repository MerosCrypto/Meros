# Merit Module

### `getHeight`

`getHeight` replies with the Blockchain's height. It takes in zero arguments and the result is an int of the height.

### `getDifficulty`

`getDifficulty` replies with the current difficulty. It takes in zero arguments and the result of a string of the difficulty.

### `getBlock`

`getBlock` replies with a Block. It takes in one argument.
- ID (int/string): Either the nonce as an int or hash as a string.

The result is an object, as follows:
- `hash`   (string)
- `header` (object)
    - `version`   (int)
    - `last`      (string)
    - `contents`  (string)
    - `verifiers` (string)
    - `miner`     (int/string): Either the miner's nick as an int or the key as a string if this is their first Block.
    - `time`      (int)
    - `proof`     (int)
    - `signature` (string)
- `transactions` (array of strings, each a Transaction hash)
- `elements`     (array of objects, each as follows)
    - `descendant` (string)
    - `holder`     (int)

        When `descendant` == "SendDifficulty":
        - `difficulty` (string)

        When `descendant` == "DataDifficulty":
        - `difficulty` (string)

        When `descendant` == "GasPrice":
        - `price` (int)

        When `descendant` == "MeritRemoval":
        - `partial`  (bool):             Whether or not the first Element is already archived on the Blockchain.
        - `elements` (array of objects): The two Elements which caused this MeritRemoval. If they're an Element which goes in a Block, they're formatted as they would be in a Block. Else....

            When `descendant` == "Verification":
                - `hash` (string)

            When `descendant` == "VerificationPacket":
                - `holders` (array of strings, each a BLS Public Key)
                - `hash` (string)
- `aggregate` (string)

### `getNickname`

`getNickname` replies with the Merit Holder's nickname. It takes in one argument.
- Merit Holder (string)

The result is an int of the nickname.

### `getPublicKey`

`getPublicKey` replies with the specified Merit Holder's BLS Public Key. It takes in one argument.
- Nickname (int)

The result is an string of the BLS Public Key.

### `getTotalMerit`

`getTotalMerit` replies with the total amount of Merit in existence. It takes in zero arguments and the result is an int of the total amount of Merit.

### `getLiveMerit`

`getLiveMerit` replies with the amount of live Merit in existence. It takes in zero arguments and the result is an int of the amount of live Merit.

### `getMerit`

`getMerit` replies with a Merit Holder's Merit. It takes in one argument.
- Merit Holder (string)

The result is an object, as follows:
- `live`      (bool): Whether or not the MeritHolder's Merit is live.
- `malicious` (bool): Whether or not the MeritHolder has an unarchived MeritRemoval.
- `merit`     (int):  Amount of Merit the MeritHolder has.

### `getBlockTemplate`

`getBlockTemplate` replies with a template for mining a Block. It takes in one argument.
- miner (string): BLS Public Key of the Miner.

The result is an object, as follows:
- `header` (string)
- `body`   (string)

Mining the Block occurs by hashing the header with an 8-byte left padded proof, despite the proof only being 4 bytes. After the initial hash, the hash is signed by the miner, and the hash is hashed with the signature as the salt. If it beats the difficulty, it can be published by appending the 4-byte proof to the header, then appending the signature to the header, then appending the body to the completed header, and then calling `merit_publishBlock` (see below).

### `publishBlock`

`publishBlock` adds the Block to the local Blockchain, and if it's valid, publishes it. It takes in one argument.
- Block (string)

The result is a bool of true.
