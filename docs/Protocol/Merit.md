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

A BlockHeader's hash is defined as follows:

```
Argon2d(
    iterations = 1,
    memory = 131072,
    parallelism = 1
    data = serialized BlockHeader without proof,
    salt = proof with no leading 0s
)
```

BlockBodies have the following fields:

- records: List of MeritHolders (BLS Public Keys), Nonces, and Merkle tree hashes.
- miners: List of Miners (BLS Public Keys) and Merit amounts to payout.

The BlockHeader's miners Merkle tree uses Blake2b-384 as a hash algorithm and consists of the the BlockBody's miners. Each leaf is the Blake2b-384 hash of a serialized miner (48-byte BLS Public Key and 1-byte amount). If there is only one leaf in the tree, the tree's hash is the leaf's hash.

Blocks have the following fields:

- header: The BlockHeader.
- body: The BlockBody.

A Block's hash is defined as its BlockHeader's hash.

Checkpoints have the following fields:

- signers: List of MeritHolders (BLS Public Keys) who signed this Block.
- aggregate: BLS Signature.

When a new Block is received, it should be tested for validity. A Meros MainNet Blockchain is valid if:

- The genesis Block's BlockBody has a:
	-  Nonce of 0.
	-  Last hash of "MEROS_MAINNET", left padded with 0s until it has a length of 48 bytes.
	-  Zeroed out aggregate field.
	-  Zeroed out miners field.
	-  Time of 0.
	-  Proof of 0.
	-  Empty list of records,
	-  Empty list of miners,
- BlockHeader nonces always increment by one as the Blockchain progresses.
- The last field of each BlockHeader is the hash of the previous Block.
- No BlockBody has multiple records for a single key.
- No BlockBody has a record with a nonce lower than the previous record for that key.
- No BlockBody has a record with a Merkle tree hash which is different than what that MeritHolder's Merkle tree hash would be for that nonce (as described in the Consensus documentation).
- No BlockBody archives a Verification for an Entry when an Entry before it has yet to be mentioned in any archived Verification and isn't mentioned in a Verification archived in this BlockBody either.
- Every BlockHeader for a BlockBody with no records has a zeroed out aggregate signature.
- Every BlockHeader for a BlockBody with records has an aggregate signature created by the following algorithm:

```
List[BLSSignature] signatures
for r in records:
	for n in previousRecordNonce[r.key] + 1 .. r.nonce:
    	signedElement = consenus[r.key][n]
        signatures.add(signedElement.signature)
    previousRecordNonce[r.key] = r.nonce
BLSSignature aggregate = signatures.aggregate()
```

- No BlockBody has a miner with an invalid key and the total of every miner in that BlockBody's amount equals 100.
- No BlockBody has a miner with an amount less than 1.
- Every BlockHeader's miners Merkle tree hash is accurate.
- Every BlockHeader's time is greater than the previous BlockHeader's time.
- Every BlockHeader's time is less than 20 minutes into the future.
- Every BlockHeader's hash beat their Difficulty.
- Every Block who's BlockHeader's nonce modulus 5 is 0 has a corresponding Checkpoint. This Checkpoint's signers should represent a majority of the live Merit (explained below), and the signature should be the aggregate signature of every signer's signature of the Block hash.

The role of Checkpoints are stop 51% attacks. An Entry can be reverted by having it verified as normal, but then wiping out all the Blocks that mention its Verifications, and adding in Blocks which have a competing Entry default. Every Entry has a checkpoint during the time it takes to default, so by not allowing the chain to advance until it gets a Checkpoint, malicious actors cannot cause an Entry to default. They do not stop chain re-organizations.

Chain re-organizations can happen if a different, valid chain has a higher cumulative difficulty. In the case the cumulative difficulties are the same, the chain who's tail Block has the higher hash is the proper Blockchain.

When a Block is added, every miner in the BlockBody's miners should get their amount of Merit. This is considered live Merit. If these new Merit Holders don't publish any Elements for an entire Checkpoint period, it is no longer live. To restore it to live, they must get an Element mentioned in a Block. This turns their Merit into Pending Merit, and their Merit will be restored to Live Merit 5 Blocks after their Element is mentioned. Pending Merit cannot be used on the Consensus DAG, but does contribute towards the amount of Live Merit, and can be used on Checkpoints. After 52560 Blocks, Merit dies. It cannot be restored. This sets a hard cap on the total supply of Merit at 5256000 Merit.

Also, when a Block is added, a new Epoch is created. An Epoch keeps track of who verified an Entry. Every Entry that is first mentioned in that Block, via its archived Verifications, is added to the new Epoch, along with the list of Merit Holders who verified it. If the Entry was mentioned in a previous Epoch, which has not yet been finalized, the newly archived Verification has its holder added to the list of Merit Holders which verified the Entry. The new Epoch is added to a list of the past 5 Epochs, and the oldest Epoch is popped off. This oldest Epoch has all of its Entries which didn't get verified removed, and is then used to calculate rewards.

In the process of calculating rewards, first every Merit Holder is assigned a score via the following code:

```
for entry in epoch:
    for verifier of epochs[entry]:
        scores[verifier] += 1

for holder in scores:
    scores[holder] *= live_merit(holder)
```

The Merit Holders are then ordered from highest score to lowest, with ties placing the Merit Holder with the higher key first. Only the top 100 Merit Holders receive Mints, with the rest of the scores rolling over to the next Block. Once the top 100 Merit Holders are identified, and the rest deleted, the scores should be normalized to 1000 as such:

```
total = sum(scores)
for holder in scores:
    scores[holder] = scores[holder] * 1000 / total
```

If the sum of every score is less than 1000, the top Merit Holder receives the difference. A negative sigmoid which uses the current difficulty for its x value produces a multiplier. Mints are then created for each Merit Holder, starting with the one who scored the highest, with an amount of `score * multiplier`.

### Checkpoint

`Checkpoint` has a variable message length; the 48 Block hash, 4-byte amount of signers, every signer's 96-byte BLS Public Key, and the 96-byte aggregate signature.

### BlockHeader

`BlockHeader` has a message length of 208 bytes; the 4-byte nonce, 48-byte last hash, 96-byte aggregate signature, 48-byte miners Merkle tree hash, 8-byte time, and 4-byte proof.

### BlockBody

`BlockBody` has a variable message length; the 4-byte amount of records, the records (each with a 48-byte BLS Public Key, 4-byte nonce, and 48-byte Merkle tree hash), 1-byte amount of miners, and the miners (each with a 48-byte BLS Public Key and 1-byte amount).

### Violations in Meros

- Meros produces the BlockHeader hash with a BlockHeader serialization containing the proof.
- Meros allows archived Verifications to skip over Entries.
- Meros produces the BlockHeader aggregate using the following algorithm:

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
- Meros doesn't support chain re-organizations.
- Meros doesn't rollover rewards or use a negative sigmoid for reward calculation.
- Meros doesn't support the `Checkpoint` message type.
