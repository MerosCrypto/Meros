# Syncing

### PeersRequest and Peers

`PeersRequest` is used to request the connection info of other Meros nodes, and has a message length of 0 bytes. The expected response is a `Peers`, which has a variable message length; the 1-byte amount of peers, and for each peer, the 4-byte IPv4 address and 2-byte port. The peers sent in a `Peers` message is completely up to the syncee.

### BlockListRequest and BlockList

`BlockListRequest` has a message length of 33 bytes; the 1-byte quantity (where the quantity requested is the byte's value plus one) and a Block's 32-byte hash. The expected response is a `BlockList` containing the hashes of the Blocks before the specified Block. The amount of hashes provided by `BlockList` will be less than the amount requested if the Block before the genesis Block is requested. `BlockList` has a variable message length; the 1-byte quantity (where the quantity is the byte's value plus one) and each 32-byte hash. If the specified Block is either the genesis Block or unknown, the syncee sends `DataMissing`.

### CheckpointRequest

`CheckpointRequest` has a message length of 32 bytes; the Block's 32-byte hash. The expected response is a `Checkpoint` containing the Checkpoint for the specified Block.

### BlockHeaderRequest

`BlockHeaderRequest` has a message length of 32 bytes; the Block's 32-byte hash. The expected response to a `BlockHeaderRequest` is a `BlockHeader` containing the requested BlockHeader.

### BlockBodyRequest

`BlockBodyRequest` has a message length of 36 bytes; the Block's 32-byte hash and a 4-byte capacity. The expected response to a `BlockBodyRequest` is a `BlockBody` containing the requested BlockBody using the specified capacity. That said, the specified capacity is not required to be used in the response.

### SketchHashesRequest and SketchHashes

`SketchHashesRequest` has a message length of 32-bytes; the Block's 32-byte hash. The expected response is a `SketchHashes` containing the sketch hashes for the specified Block. `SketchHashes` has a variable message length; the 4-byte amount of hashes and each 8-byte hash.

### SketchHashRequests

`SketchHashRequests` has a variable message length; the Block's 32-byte hash, the 4-byte amount of sketch hashes, and each 8-byte sketch hash. The expected response is multiple `VerificationPacket` messages, each containing the VerificationPacket which created the matching sketch hash in the specified Block. If a hash isn't found, and a `DataMissing` is sent, the entire line of requests is terminated.

### TransactionRequest

`TransactionRequest` has a message length of 32 bytes; the Transaction's 32-byte hash. The expected response is a `Claim`, `Send`, or `Data` containing the requested Transaction. If a Mint has the requested hash, the syncee sends `DataMissing`.

### DataMissing

`DataMissing` has a message length of 0 and is a valid response to any request. It signifies the syncee doesn't have the requested data.

### SyncingOver

`SyncingOver` has a message length of 0 and ends syncing.

### Violations in Meros

- Meros doesn't support the `CheckpointRequest` message type.
