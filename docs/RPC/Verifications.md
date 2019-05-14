# Verifications Module

### `getVerification`
`getVerification` will fetch and return the hash of a specified verification. It takes in two arguments:
- Verifier (string)

### `getUnarchivedVerifications`
`getUnarchivedVerifications` will fetch and return all accounts with unarchived verifications. It takes in zero arguments and returns an array of objects, each as follows:
- `verifier`  (string)
- `nonce`     (int)
- `merkle`    (string)
- `signature` (string)
