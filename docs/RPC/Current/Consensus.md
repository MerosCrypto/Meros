# Consensus Module

### `getHeight`

`getHeight` replies with the specified Merit Holder's height. It takes in one argument:
- Merit Holder (string)

The result is an int of the height.

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

    When `descendant` == "MeritRemoval":
    - `partial`  (string):           Whether or not the first Element is already archived on the Blockchain.
    - `elements` (array of objects): The two Elements which caused this MeritRemoval.

### `getStatus`

`getStatus` replies with the specified Transaction's status (as long as it's still in Epochs), from how much Merit it has, how much Merit is needs to become verified, if it's verified, and if non-defaulted Verification is impossible. It takes in one argument:
- Hash (string)

The result is an object, as follows:
- `merit`      (int):  Merit of all the Merit Holders who verified this Transaction.
- `threshold`  (int):  Merit needed to become verified.
- `verified`   (bool): Whether or not the Transaction is verified.
- `defaulting` (bool): Whether or not the Transaction is able to become verified by crossing its threshold or if it can only be verified at the end of its Epoch.
