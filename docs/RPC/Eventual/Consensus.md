# Consensus Module

### `getElement`

`getElement` replies with the specified Element. It takes in two arguments:
- Merit Holder (string)
- Nonce        (int):    If the Element is an unarchived MeritRemoval, this will be 0.

The result is an object, as follows:
- `descendant` (string)
- `holder`     (string)
- `nonce`      (int)

    When `descendant` == "Verification":
    - `hash` (string)

    When `descendant` == "SendDifficulty":
    - `difficulty` (string)

    When `descendant` == "DataDifficulty":
    - `difficulty` (string)

    When `descendant` == "GasPrice":
    - `price` (int)

    When `descendant` == "MeritRemoval":
    - `partial`  (string):           Whether or not the first Element is already archived on the Blockchain.
    - `elements` (array of objects): The two Elements which caused this MeritRemoval.

### `getSendDifficulty`

`getSendDifficulty` replies with the current Send difficulty. It takes in zero arguments and the result of a string of the difficulty.

### `getDataDifficulty`

`getDataDifficulty` replies with the current Data difficulty. It takes in zero arguments and the result of a string of the difficulty.

### `getStatus`

`getStatus` replies with the specified Transaction's status, from how much Merit it has, how much Merit is needs to become verified, if it's verified, and if non-defaulted Verification is impossible. It takes in one argument:
- Hash (string)

The result is an object, as follows:
- `merit`      (int):  Merit of all the Merit Holders who verified this Transaction.
- `threshold`  (int):  Merit needed to become verified.
- `verified`   (bool): Whether or not the Transaction is verified.
- `defaulting` (bool): Whether or not the Transaction is able to become verified by crossing its threshold or if it can only be verified at the end of its Epoch.

### `getVerifiers`

`getVerifiers` replies with the Merit Holders who verified a Transaction still in Epochs. It takes in one argument:
- Hash (string)

The result is an array of strings, each a Merit Holder's BLS Public Key.

### `publishSignedVerification`

`publishSignedVerification` parses the serialized Signed Verification, adds it to the local Consensus DAG, and if it's valid, publishes it. It takes in one argument.
- Signed Verification (string)

The result is a bool of true.

### `publishSignedSendDifficulty`

`publishSignedSendDifficulty` parses the serialized Signed Send Difficulty, adds it to the local Consensus DAG, and if it's valid, publishes it. It takes in one argument.
- Signed Send Difficulty (string)

The result is a bool of true.

### `publishSignedDataDifficulty`

`publishSignedDataDifficulty` parses the serialized Signed Data Difficulty, adds it to the local Consensus DAG, and if it's valid, publishes it. It takes in one argument.
- Signed Data Difficulty (string)

The result is a bool of true.

### `publishSignedGasPrice`

`publishSignedGasPrice` parses the serialized Signed Gas Price, adds it to the local Consensus DAG, and if it's valid, publishes it. It takes in one argument.
- Signed Gas Price (string)

The result is a bool of true.

### `publishSignedMeritRemoval`

`publishMeritRemoval` parses the serialized Signed Merit Removal, adds it to the local Consensus DAG, and if it's valid, publishes it. It takes in one argument.
- Signed Merit Removal (string)

The result is a bool of true.
