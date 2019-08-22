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

    When `descendant` == "MeritRemoval":
    - `partial`  (string):           Whether or not the first Element is already archived on the Blockchain.
    - `elements` (array of objects): The two Elements which caused this MeritRemoval.

### `getHeight`

`getHeight` replies with the specified Merit Holder's height. It takes in one argument:
- Merit Holder (string)

The result is an int of the height.
