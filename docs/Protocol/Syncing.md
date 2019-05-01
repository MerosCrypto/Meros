# Syncing

Syncing is an state between two nodes where one needs to catch up. To initiate syncing, the node missing data (the "syncer") sends `Syncing`. In response, the node which received `Syncing` (the "syncee") sends `SyncingAcknowledged`. The syncer should ignore all messages from the syncee until it receives `SyncingAcknowledged`, in order to not confuse normal network traffic with data relevant to its syncing.

During syncing, the syncer can only send:
- `EntryRequest`
- `MemoryVerificationRequest`
- `BlockRequest`
- `VerificationRequest`
- `SyncingOver`

The syncee can only send:
- `DataMissing`
- `Claim`
- `Send`
- `Receive`
- `Data`
- `MemoryVerification`
- `Block`
- `Verification`

The syncee should also only send messages in direct response to a request from the syncer.

### `Syncing` and `SyncingAcknowledged`

Both `Syncing` and `SyncingAcknowledged` have a message length of zero. After receiving `SyncingAcknowledged`, the syncer may send requests for missing data, one at a time. Sending multiple requests before receiving a response to the first request will lead to undefined behavior.

### `DataMissing`

`DataMissing` has a message length of zero and is a valid response to any request. It signifies the syncee doesn't have the requested data.

### `EntryRequest`

A `EntryRequest` is followed by the 48 byte Entry hash, with an expected response being a `Claim`, `Send`, `Receive`, or `Data` containing the Entry with the same hash. If a `Mint` has the requested hash, the syncer should send `DataMissing`.

### `MemoryVerificationRequest`

A `MemoryVerificationRequest` has a message length of 52 bytes; the 48 byte Verifier public key followed by the 4 byte nonce of the verification, with an expected response being a `MemoryVerification` containing the memory verification at the requested location. If a verifier had multiple verifications at that location, the syncer should respond with a `MeritRemoval` containing every memory verification at that index.

### `BlockRequest`

A `BlockRequest` is followed by the 48 byte block hash, with an expected response being a `Block` containing the block, or if the syncee doesn't have the block in question, a `DataMissing`.

### `VerificationRequest`

A `VerificationRequest` is identical to a `MemoryVerificationRequest`, except for the fact that is a verifier has a singular verification at the requested nonce, the expected response is a `Verification` containing the verification at the requested location.

### Violations in Meros

- Meros doesn't support the `MemoryVerificationRequest` message type.
- Meros doesn't support the `MeritRemoval`  message type.
- A `BlockRequest` is followed by four bytes representing the nonce of the block, as Meros currently doesn't support chain reorgs in any form.
