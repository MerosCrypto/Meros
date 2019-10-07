# Syncing

Syncing is a state between two nodes where one needs to catch up. To initiate syncing, the node missing data (the "syncer") sends `Syncing`. In response, the node which received `Syncing` (the "syncee") sends `SyncingAcknowledged`. `SyncingAcknowledged` exists so the syncer doesn't confuse normal network traffic with responses to the data it requests to sync.

During syncing, the syncer can only send:

- `Handshake`

- `PeersRequest`
- `BlockListRequest`

- `CheckpointRequest`
- `BlockHeaderRequest`
- `BlockBodyRequest`

- `VerificationPacketRequest`
- `TransactionRequest`

- `SignedVerificationPacketRequest` (disabled)

- `SyncingOver`

The syncee can only send:

- `BlockchainTail`

- `Peers`
- `BlockList`

- `DataMissing`

- `Claim`
- `Send`
- `Data`
- `Lock`
- `Unlock`

- `SignedVerificationPacket` (disabled)

- `Checkpoint`
- `BlockHeader`
- `BlockBody`
- `VerificationPacket`

The syncee only sends messages in direct response to a request from the syncer.

### Syncing and SyncingAcknowledged

Both `Syncing` and `SyncingAcknowledged` have a message length of 0. After receiving `SyncingAcknowledged`, the syncer may send requests for missing data, one at a time. Sending multiple requests before receiving a response to the first request will lead to undefined behavior.

### PeersRequest and Peers

`PeersRequest` is used to request the connection info of other Meros nodes, and has a message length of 0 bytes. The expected response is a `Peers`, which has a variable message length; the 1-byte amount of peers, and for each peer, the 4-byte IPv4 address and 2-byte port. The peers sent in a `Peers` message is completely up to the syncee.

### BlockListRequest and BlockList

`BlockListRequest` has a message length of 50 bytes; 1-byte of 0, to request Blocks before the specified Block, or 1 to request Blocks after the specified Block, 1-byte quantity, and the 48-byte hash of the Block to work off of. The expected response is a `BlockList` containing the Blocks before/after the specified Block, where the first hash is the specified Block. The amount of hashes provided by `BlockList` may be less than the amount requested if the genesis Block or the tail Block is reached. `BlockList` has a variable message length; the 1-byte amount of hashes and each 48-byte hash.

### CheckpointRequest

`CheckpointRequest` has a message length of 48 bytes; the Block's 48-byte hash. The expected response is a `Checkpoint` containing the Checkpoint for the specified Block.

### BlockHeaderRequest and BlockBodyRequest

`BlockHeaderRequest` and `BlockBodyRequest` both have a message length of 48 bytes; the Block's 48-byte hash. The expected response to a `BlockHeaderRequest` is a `BlockHeader` with the requested BlockHeader. The expected response to a `BlockBodyRequest` is a `BlockBody` containing the requested Block's body.

### VerificationPacketRequest

`VerificationPacketRequest` has a message length of 96 bytes; the hash of the Block the VerificationPacket is archived in, and the hash of the Transaction it includes Verifications for. The expected response is a `VerificationPacket` for the specified Transaction including the Verifications archived in the specified Block.

### TransactionRequest

`TransactionRequest` has a message length of 48 bytes; the Transaction's 48-byte hash. The expected response is a `Claim`, `Send`, or `Data` containing the requested Transaction. If a Mint has the requested hash, the syncer sends `DataMissing`.

### SignedVerificationPacketRequest

`SignedVerificationPacketRequest` has a message length of 48 bytes; the Transaction's 48-byte hash. The expected response would be a `SignedVerificationPacket` for the specified Transaction or `DataMissing` if the requested VerificationPacket has already had its signature aggregated in a Block. That said, the expected response is a disconnect because this message is disabled, just as `SignedVerificationPacket` is.

### DataMissing

`DataMissing` has a message length of 0 and is a valid response to any request. It signifies the syncee doesn't have the requested data.

### SyncingOver

`SyncingOver` has a message length of 0 and ends syncing.

### Violations in Meros

- Meros doesn't support the `PeersRequest` and `Peers` message types.
- Meros doesn't support the `CheckpointRequest` message type.
- Meros doesn't support the `VerificationPacketRequest` message types.
