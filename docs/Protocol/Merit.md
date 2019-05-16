# Merit

Merit is a blockchain used to:

- Archive Consensus, providing a complete overview, which then provides nodes with a complete overview of the Lattice.
- Distribute Merit.
- Mint new Meros.

BlockHeaders have the following fields:

- nonce: Nonce of the Block.
- last: Last Block Hash.
- aggregate: Aggregated BLS Signature of every Element this Block archives.
- miners: Merkle tree hash of the Miners who earned this Block's Merit.
- time: Time this Block was mined at.
- proof: Arbitrary data used to beat the difficulty.

Blocks have the following fields:

- header: Block's BlockHeader.
- records: List of MeritHolders (BLS Public Keys), Nonces, and Merkle tree hashes.
- miners: List of Miners (BLS Public Keys) and Merit amounts to payout.

A Block's hash is defined as follows:

```
Argon2d(
    iterations = 1,
    memory = 131072,
    parallelism = 1
    data = serialized BlockHeader without proof,
    salt = proof with no leading 0s
)
```

Checkpoints have the following fields:

- signers: List of MeritHolders (BLS Public Keys) who signed this Block.
- aggregate: BLS Signature.

When a new Block is received, it should be tested for validity. A Meros MainNet Blockchain is valid if:

- The genesis block has a:
	-  Nonce of 0.
	-  Last hash of "MEROS_MAINNET", left padded with 0s until it has a length of 48 bytes.
	-  0'd out aggregate field.
	-  0'd out miners field.
	-  Time of 0.
	-  Proof of 0.
	-  Empty list of records,
	-  Empty list of miners,
- BlockHeader nonces always increment by one as the blockchain progresses.
- The last field of each BlockHeader is the hash of the previous Block.
- No Block has multiple records for a single key.
- No Block has a record with a nonce lower than the previous record for that key.
- No Block has a record with an invalid Merkle tree hash (as described in the Consensus documentation).
- No Block archives a Verification for an Entry when an Entry before it has yet to be mentioned in any archived Verification and isn't mentioned in a Verification archived in this Block either.
- Every BlockHeader for a Block with no records has a 0'd out aggregate signature.
- Every BlockHeader for a Block with records has an aggregate signature created by the following algorithm:

```
List[BLSSignature] signatures
for r in records:
	for n in previousRecordNonce[r.key] + 1 .. r.nonce:
    	signedElement = consenus[r.key][n]
        signatures.add(signedElement.signature)
    previousRecordNonce[r.key] = r.nonce
BLSSignature aggregate = signatures.aggregate()
```

- No Block has a miner with an invalid key and the total of every miner in that Block's amount equals 100.
- No Block has a miner with an amount less than 1.
- Every BlockHeader's miners Merkle tree hash is accurate.
- Every BlockHeader's time is greater than the previous BlockHeader's time.
- Every BlockHeader's time is less than 20 minutes into the future.
- Every BlockHeader's hash beat their Difficulty.
- Every Block who's nonce modulus 5 is 0 has a corresponding Checkpoint. This Checkpoint's signers should represent a majority of the live Merit (explained below), and the signature should be the aggregate signature of every signer's signature of the Block hash.

The role of Checkpoints are stop 51% attacks. An Entry can be reverted by having it verified as normal, but then wiping out all the Blocks that mention its Verifications, and adding in Blocks which have a competing Entry default. Every Entry has a checkpoint during the time it takes to default, so by not allowing the chain to advance until it gets a Checkpoint, malicious actors cannot cause an Entry to default. They do not stop chain re-organizations.

Chain re-organizations can happen if a different, valid chain has a higher cumulative difficulty. In the case the cumulative difficulties are the same, the chain who's tail Block has the higher is the proper blockchain.

When a Block is added, every miner in miners should get their amount of Merit. This is considered live Merit. If these new Merit Holders don't publish any Elements for an entire Checkpoint period, it is no longer live. To restore it to live, they must get an Element mentioned in a Block. This turns their Merit into Pending Merit, and their Merit will be restored to Live Merit 5 Blocks after their Element is mentioned. Pending Merit cannot be used on the Consensus DAG, but does contribute towards the amount of Live Merit, and can be used on Checkpoints. After 52560 Blocks, Merit dies. It cannot be restored. This sets a hard cap on the total supply of Merit at 5256000 Merit.

### BlockHeader

`BlockHeader` has a message length of 208 bytes; the 4 byte nonce, 48 byte last hash, 96 byte aggregate signature, 48 byte miners Merkle tree hash, 8 byte time, and 4 byte proof.

### Block

`Block` has a variable message length; the 208 byte BlockHeader (serialized as described above), 4 byte amount of records, the records (each with a 48 byte BLS Public Key, 4 byte nonce, and 48 byte Merkle tree hash), 1 byte amount of miners, and the miners (each with a 48 byte BLS Public Key and 1 byte amount).

### Checkpoint

`Checkpoint` has a variable message length; the 48 Block hash, 4 byte amount of signers, every signer's 96 byte BLS Public Key, and the 96 byte aggregate signature.

### Violations in Meros

- Meros produces the Block hash with a BlockHeader serialization containing the proof.
- Meros allows archived Verifications to skip over Entries.
- Meros produces the Block aggregate using the following algorithm:

```
List[BLSSignature] verifierSignatures
for r in records:
	for n in previousRecordNonce[r.key] + 1 .. r.nonce:
    	signedElement = consenus[r.key][n]
        elementSignatures.add(signedElement.signature)

    verifierSignatures.add(elementSignatures.aggregate())
    previousRecordNonce[r.key] = r.nonce

BLSSignature aggregate = verifierSignatures.aggregate()
```

- Meros doesn't support dead Merit.
- Meros doesn't support the `BlockHeader` message type.
- Meros doesn't support the `Checkpoint` message type.
