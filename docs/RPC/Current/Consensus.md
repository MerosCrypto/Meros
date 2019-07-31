# Consensus Module

### `getElement`

`getElement` replies with the specified Element. It takes in two arguments:
- Merit Holder (string)
- Nonce        (int)

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
    - `elements` (array of objects): The two Elements which caused this MeritRemoval.
