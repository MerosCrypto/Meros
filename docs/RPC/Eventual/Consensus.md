# Consensus Module

### `getSendDifficulty`

`getSendDifficulty` replies with the current Send Difficulty. It takes in one argument:
- Merit Holder (string): Optional; defaults to null.

The result is a string of the difficulty if the Merit Holder is null, or if it isn't, what the specified Merit Holder voted.

### `getDataDifficulty`

`getDataDifficulty` replies with the current Data Difficulty. It takes in one argument:
- Merit Holder (string): Optional; defaults to null.

The result is a string of the difficulty if the Merit Holder is null, or if it isn't, what the specified Merit Holder voted.

### `getGasPrice`

`getGasPrice` replies with the current Gas Price. It takes in one argument:
- Merit Holder (string): Optional; defaults to null.

The result is int of the gas price if the Merit Holder is null, or if it isn't, what the specified Merit Holder voted.

### `getVerifications`

`getVerifications` replies with the Verifications for the specified Transaction. It takes in one argument:
- hash (string)

The result is an object, as follows:
- `verifiers`  (array of strings): The list of verifiers for this Transaction.
- `merit`      (int):              Merit of all the Merit Holders who verified this Transaction.
- `threshold`  (int):              Merit needed to become verified.
- `verified`   (bool):             Whether or not the Transaction is verified.
- `defaulting` (bool):             Whether or not the Transaction is able to become verified by crossing its threshold or if it can only be verified at the end of its Epoch.

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
