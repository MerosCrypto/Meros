# Consensus Module

### `getStatus`

`getStatus` replies with the Status for the specified Transaction. It takes in one argument:
- hash (string)

The result is an object, as follows:
- `verifiers`  (array of strings): The list of verifiers for this Transaction.
- `merit`      (int):              Merit of all the Merit Holders who verified this Transaction.
- `threshold`  (int):              Merit needed to become verified.
- `verified`   (bool):             Whether or not the Transaction is verified.
- `defaulting` (bool):             Whether or not the Transaction is able to become verified by crossing its threshold or if it can only be verified at the end of its Epoch.
