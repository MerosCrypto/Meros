# Consensus Module

### `getSendDifficulty`

`getSendDifficulty` replies with a Send Difficulty. It takes in zero arguments and the result is an int of the current difficulty.

### `getDataDifficulty`

`getDataDifficulty` replies with a Data Difficulty. It takes in zero arguments and the result is an int of the current difficulty.

### `getStatus`

`getStatus` replies with the Status for the specified Transaction. It takes in one argument:
- hash (string)

The result is an object, as follows:
- `verifiers`  (array of strings): The list of verifiers for this Transaction.
- `merit`      (int):              Merit of all the Merit Holders who verified this Transaction.
- `threshold`  (int):              Merit needed to become verified.
- `verified`   (bool):             Whether or not the Transaction is verified.
- `competing`  (bool):             Whether or not the Transaction has competitors. If it does, and isn't already verified, it can only be verified at the end of its Epoch.
- `beaten`     (bool):             Whether or not the Transaction was finalized, with a different, competing, Transaction having more Merit.
