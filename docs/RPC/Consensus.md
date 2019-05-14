# Consensus Module

### `getElement`
`getElement` will fetch and return the hash of a specified verification. It takes in two arguments:
- Verifier (string)
- Nonce    (int)
It returns:
- `hash` (string)

### `getUnarchivedMeritHolderRecords`
`getUnarchivedMeritHolderRecords` will fetch and return all MeritHolderRecords for all MeritHolders with unarchived Elements (plus an aggregate signature). It takes in zero arguments and returns an array of objects, each as follows:
- `holder`    (string)
- `nonce`     (int)
- `merkle`    (string)
- `signature` (string)
