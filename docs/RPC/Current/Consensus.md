# Consensus Module

### `getElement`
`getElement` will fetch and return the hash of a specified verification. It takes in two arguments:
- Verifier (string)
- Nonce    (int)
It returns:
- `descendant` (string)
- `holder`     (string)
- `nonce`      (int)

When `descendant` == "verification":
    - `hash` (string)

### `getUnarchivedRecords`
`getUnarchivedMeritHolderRecords` will fetch and return all MeritHolderRecords for all MeritHolders with unarchived Elements (plus an aggregate signature). It takes in zero arguments and returns:
- `records` (array of objects, each as follows)
    - `holder`    (string)
    - `nonce`     (int)
    - `merkle`    (string)
- `aggregate` (string)
