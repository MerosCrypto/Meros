# Syncing

Syncing is a state between two nodes where one needs to catch up. To initiate syncing, the node missing data (the "syncer") sends `Syncing`. In response, the node which received `Syncing` (the "syncee") sends `SyncingAcknowledged`. The syncer should ignore all messages from the syncee until it receives `SyncingAcknowledged`, in order to not confuse normal network traffic with data relevant to its syncing.

During syncing, the syncer can only send:

- `Handshake`

- `PeerRequest`

- `CheckpointRequest`
- `BlockHeaderRequest`
- `BlockBodyRequest`

- `ElementRequest`

- `TransactionRequest`

- `GetBlockHash`
- `GetVerifierHeight`

- `SignedElementRequest`

- `SyncingOver`

The syncee can only send:

- `BlockHeight`

- `Peers`

- `Checkpoint`
- `BlockHeader`
- `BlockBody`

- `Verification`
- `SendDifficulty`
- `DataDifficulty`
- `GasPrice`
- `MeritRemoval`

- `Claim`
- `Send`
- `Data`
- `Lock`
- `Unlock`

- `BlockHash`
- `VerifierHeight`

- `SignedVerification`
- `SignedSendDifficulty`
- `SignedDataDifficulty`
- `SignedGasPrice`
- `SignedMeritRemoval`

- `DataMissing`

The syncee only sends messages in direct response to a request from the syncer.

### Syncing and SyncingAcknowledged

Both `Syncing` and `SyncingAcknowledged` have a message length of 0. After receiving `SyncingAcknowledged`, the syncer may send requests for missing data, one at a time. Sending multiple requests before receiving a response to the first request will lead to undefined behavior.

### PeerRequest and Peers

`PeerRequest` is used to request the connection info of other Meros nodes, and has a message length of 0 bytes. The expected response is a `Peers`, which has a variable message length; the 1-byte amount of peers, and for each peer, the 4-byte IPv4 address and 2-byte port. The peers sent in a `Peers` message is completely up to the syncee.

### CheckpointRequest

`CheckpointRequest` has a message length of 48 bytes; the Block's 48-byte hash. The expected response is a `Checkpoint` containing the Checkpoint for the specified Block.

### BlockHeaderRequest and BlockBodyRequest

`BlockHeaderRequest` and `BlockBodyRequest` both have a message length of 48 bytes; the Block's 48-byte hash. The expected response to a `BlockHeaderRequest` is a `BlockHeader` with the requested BlockHeader. The expected response to a `BlockBodyRequest` is a `BlockBody` containing the requested Block's body. If a zeroed out hash is provided in a `BlockHeaderRequest`, the syncee responds with a `BlockHeader` containing the syncee's tail BlockHeader.

### ElementRequest

`ElementRequest` has a message length of 52 bytes; the Verifier's 48-byte BLS Public Key and the Element's 4-byte nonce. The expected response is a `Verification`, `SendDifficulty`, `DataDifficulty`, `GasPrice`, or `MeritRemoval`, containing the Element, without its BLS Signature.

### TransactionRequest

`TransactionRequest` has a message length of 48 bytes; the Transaction's 48-byte hash. The expected response is a `Claim`, `Send`, or `Data` containing the requested Transaction. If a Mint has the requested hash, the syncer sends `DataMissing`.

### GetBlockHash and BlockHash

`GetBlockHash` has a message length of 4 bytes; the nonce of the Block. The expected response is a `BlockHash` containing the Block at the specified nonce's hash. `BlockHash` has a message length of 48 bytes; the 48-byte hash. If a zeroed out nonce was sent, the syncee responds with a `BlockHash` containing the syncee's tail Block's nonce and hash.

### GetVerifierHeight and VerifierHeight

`GetVerifierHeight` has a message length of 48 bytes; the Verifier's 48-byte BLS Public Key. The expected response is a `VerifierHeight`, containing the height of the specified Verifier. `VerifierHeight` has a message length of 52 bytes; the Verifier's 48-byte BLSPublicKey and the Verifier's 4-byte height.

### SignedElementRequest

`SignedElementRequest` has a message length of 52 bytes; the Verifier's 48-byte BLS Public Key and the Element's 4-byte nonce. The expected response is a `SignedVerification`, `SignedSendDifficulty`, `SignedDataDifficulty`, `SignedGasPrice`, or `SignedMeritRemoval`, containing the Element at the requested location, including its BLS Signature. If the request Element has already had its signature aggregated in a Block, the syncer sends `DataMissing`.

### DataMissing

`DataMissing` has a message length of 0 and is a valid response to any request. It signifies the syncee doesn't have the requested data.

### SyncingOver

`SyncingOver` has a message length of 0 and ends syncing.

### Violations in Meros

- Meros doesn't support the `PeerRequest` and `Peers` message types.
- Meros doesn't support the `CheckpointRequest` message type.
- Meros doesn't support the `GetVerifierHeight` and `VerifierHeight` message types.
- Meros's Consensus DAG only supports Verification and SignedVerifications. Therefore, it will only answer an `ElementRequest` with one of the two.
- Meros doesn't support the `SignedElementRequest` message type.
