# Syncing

### Syncing

`Syncing` is described in the Handshake documentation.

### PeersRequest and Peers

`PeersRequest` is used to request the connection info of other Meros nodes, and has a message length of 0 bytes. The expected response is a `Peers`, which has a variable message length; the 1-byte amount of peers, and for each peer, the 4-byte IPv4 address and 2-byte port. The peers sent in a `Peers` message is completely up to the syncee.

### BlockListRequest and BlockList

`BlockListRequest` has a message length of 34 bytes; 1-byte of 0, to request Blocks before the specified Block, or 1 to request Blocks after the specified Block, 1-byte quantity (where the quantity is the byte's value plus one), and the 32-byte hash of the Block to work off of. The expected response is a `BlockList` containing the Blocks before/after the specified Block. The amount of hashes provided by `BlockList` may be less than the amount requested if the genesis Block or the tail Block is reached. `BlockList` has a variable message length; the 1-byte quantity (where the quantity is the byte's value plus one) and each 32-byte hash. If there are no Blocks before/after the specified Block (depending on the requested direction), the syncee sends `DataMissing`.

### CheckpointRequest

`CheckpointRequest` has a message length of 32 bytes; the Block's 32-byte hash. The expected response is a `Checkpoint` containing the Checkpoint for the specified Block.

### BlockHeaderRequest and BlockBodyRequest

`BlockHeaderRequest` and `BlockBodyRequest` both have a message length of 32 bytes; the Block's 32-byte hash. The expected response to a `BlockHeaderRequest` is a `BlockHeader` containing the requested BlockHeader. The expected response to a `BlockBodyRequest` is a `BlockBody` containing the requested BlockBody.

### SketchHashesRequest and SketchHashes

`SketchHashesRequest` has a message length of 32-bytes; the Block's 32-byte hash. The expected response is a `SketchHashes` containing the sketch hashes for the specified Block. `SketchHashes` has a variable message length; the 4-byte amount of hashes and each 8-byte hash.

### SketchHashRequests

`SketchHashRequests` has a variable message length; the Block's 32-byte hash, the 4-byte amount of sketch hashes, and each 8-byte sketch hash. The expected response is multiple `VerificationPacket` messages, each containing the VerificationPacket which created the matching sketch hash in the specified Block. If a hash isn't found, and a `DataMissing` is sent, the entire line of requests is terminated.

### TransactionRequest

`TransactionRequest` has a message length of 32 bytes; the Transaction's 32-byte hash. The expected response is a `Claim`, `Send`, or `Data` containing the requested Transaction. If a Mint has the requested hash, the syncee sends `DataMissing`.

### DataMissing

`DataMissing` has a message length of 0 and is a valid response to any request, except `PeersRequest`. It signifies the syncee doesn't have the requested data.

### SyncingOver

`SyncingOver` has a message length of 0 and ends syncing.

### Violations in Meros

- Meros doesn't support the `BlockListRequest` forwards mode.
- Meros doesn't support the `CheckpointRequest` message type.
