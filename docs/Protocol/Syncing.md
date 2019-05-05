# Syncing

Syncing is a state between two nodes where one needs to catch up. To initiate syncing, the node missing data (the "syncer") sends `Syncing`. In response, the node which received `Syncing` (the "syncee") sends `SyncingAcknowledged`. The syncer should ignore all messages from the syncee until it receives `SyncingAcknowledged`, in order to not confuse normal network traffic with data relevant to its syncing.

During syncing, the syncer can only send:

- `GetAccountHeight`
- `GetHashesAtIndex`
- `GetVerifierHeight`
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
- `Lock`
- `Unlock`
- `MemoryVerification`
- `Block`
- `Verification`

The syncee should also only send messages in direct response to a request from the syncer.

### Syncing and SyncingAcknowledged

Both `Syncing` and `SyncingAcknowledged` have a message length of zero. After receiving `SyncingAcknowledged`, the syncer may send requests for missing data, one at a time. Sending multiple requests before receiving a response to the first request will lead to undefined behavior.

### DataMissing

`DataMissing` has a message length of zero and is a valid response to any request. It signifies the syncee doesn't have the requested data.

### EntryRequest

An `EntryRequest` has a message length of 48 bytes; the Entry hash, with the expected response being a `Claim`, `Send`, `Receive`, or `Data` containing the Entry with the same hash. If a Mint has the requested hash, the syncer should send `DataMissing`.

### MemoryVerificationRequest

A `MemoryVerificationRequest` has a message length of 52 bytes; the 48 byte Verifier public key followed by the 4 byte nonce of the Verification, with the expected response being a `MemoryVerification` containing the MemoryVerification at the requested location. If a verifier had multiple Verifications at that location, the syncee should respond with a `MeritRemoval` containing any two MemoryVerifications at that index.

### BlockRequest

A `BlockRequest` is followed by the 48 byte Block hash, with the expected response being a `Block` containing the Block. If a zero'd out hash is provided, the syncee should respond with a `Block` containing their tail Block.

### VerificationRequest

A `VerificationRequest` is identical to a `MemoryVerificationRequest`, except for the fact that if a verifier has a singular Verification at the requested nonce, the expected response is a `Verification` containing the Verification at the requested location.

### Violations in Meros

- Meros doesn't support the `MemoryVerificationRequest` message type.
- Meros doesn't support the `MeritRemoval` message type.
- A `BlockRequest` is followed by four bytes representing the nonce of the Block, as Meros currently doesn't support chain reorgs in any form. To get the tail Block, Meros sends four zero bytes.
