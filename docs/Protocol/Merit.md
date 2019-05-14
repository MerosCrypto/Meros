# Merit

# BlockHeader

BlockHeaders have the following fields:

- nonce: Nonce of the Block,
- last: Last Block Hash.
- aggregate: Aggregated BLSSignature of every Element this Block archives.
- miners: Merkle tree hash of the Miners who earned this Block's Merit.
- time: Time this Block was mined at.
- proof: Arbitrary data used to beat the difficulty.

`BlockHeader` has a message length of 208 bytes; the 4 byte nonce, the 48 byte last hash, the 96 byte aggregate signature, the 48 byte miners Merkle tree hash, the 8 byte time, and the 4 byte proof.

# Block

Blocks have the following fields:

- header: Block's BlockHeader.
- records: List of MeritHolders (BLS Public Keys), Nonces, and Merkle tree hashes.
- miners: List of Miners (BLS Public Keys) and Merit amounts to payout.

`Block` has a variable message length; the 208 byte BlockHeader (serialized as described above), the 4 byte amount of records, the records (each with a 48 byte BLS Public Key, 4 byte nonce, and 48 byte Merkle tree hash), the 1 byte amount of miners, and the miners (each with a 48 byte BLS Public Key and 1 byte amount).
