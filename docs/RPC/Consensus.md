# Consensus Module

### `getSendDifficulty`

`getSendDifficulty` replies with the Send Difficulty.

Arguments:
- `holder` (int): Optional.

The result is an int of the current difficulty if the Merit Holder isn't specified. If one is, the result is an int of what the specified Merit Holder voted.

### `getDataDifficulty`

`getDataDifficulty` replies with the Data Difficulty.

Arguments:
- `holder` (int): Optional.

The result is an int of the current difficulty if the Merit Holder isn't specified. If one is, the result is an int of what the specified Merit Holder voted.

### `getStatus`

`getStatus` replies with the Status for the specified Transaction.

Arguments:
- `hash` (string)

The result is an object, as follows:
- `verifiers`  (array of strings): The list of verifiers for this Transaction.
- `merit`      (int):              Sum of the Merit of the verifiers. Doesn't include any verifiers who have a pending Merit Removal.
- `threshold`  (int):              Merit needed to become verified.
- `verified`   (bool):             Whether or not the Transaction is verified.
- `competing`  (bool):             Whether or not the Transaction has competitors. If it does, and isn't already verified, it can only be verified at the end of its Epoch.
