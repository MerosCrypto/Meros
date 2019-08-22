# Merit

Merit is a blockchain used to:

- Archive Consensus, providing a complete overview, which then provides nodes with a complete overview of the Transactions.
- Distribute Merit.
- Mint new Meros.

### BlockHeader Data Type

BlockHeaders exist in order to prove Block validity without syncing and verifying the entire Block, a needed feature for both highly performant networks and light clients.

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
    salt = proof left padded to be 8 bytes long
)
```

### Block Data Type

Blocks are the backbone of every blockchain. In Meros, they reference the latest Element on a MeritHolder, with a verifiable proof of every Element the MeritHolder has created, thereby archiving the Consensus DAG, and specify who to reward with the newly-mined Merit.

Blocks have the following fields:

- header: Block Header.
- records: List of Merit Holders (BLS Public Keys), Nonces, and Merkle tree hashes.
- miners: List of Miners (BLS Public Keys) and Merit amounts to payout.

A Block's hash is defined as its BlockHeader's hash.

The genesis Block on the Meros mainnet Blockchain has a:
- nonce of 0.
- last of “MEROS_MAINNET” left padded with 0 bytes until it has a length of 48 bytes.
- Zeroed out aggregate signature.
- Zeroed out miners merkle hash.
- time of 0.
- proof of 0.
- Empty list of records.
- Empty list of miners.

### Checkpoint Data Type

Checkpoints mitigate 51% attacks. By requiring the majority of Merit Holders, by weight, to agree on every 5th block, and not allowing the Blockchain to advance without a Checkpoint, a 51% attack would need to have not just 51% of the hash power, but 51% of the Merit. In order to obtain that much Merit, an attacker would need to sustain the attack for an entire year. Checkpoints do not stop chain reorganizations.

Checkpoints have the following fields:

- signers: List of MeritHolders (BLS Public Keys) who signed this Block.
- aggregate: BLS Signature.

### BlockHeader

When a new BlockHeader is received, it's tested for validity. The BlockHeader is valid if:

- nonce must be equivalent to the current Blockchain height.
- last must be equivalent to the hash of the current tail Block.
- time must be greater than the current Block’s time.
- time must be less than 20 minutes into the future.
- hash must beat the current difficulty.

If the BlockHeader is valid, full nodes sync the rest of the Block via a `BlockBodyRequest`.

`BlockHeader` has a message length of 204 bytes; the 4-byte nonce, 48-byte last hash, 96-byte aggregate signature, 48-byte miners Merkle tree hash, 4-byte time, and 4-byte proof.

### BlockBody

When a new BlockBody is received, a full Block can be formed using the BlockHeader. The Block is valid if:

- If the Block has no records, the BlockHeader has a zeroed aggregate signaure.
- If the Block has records, the BlockHeader has an aggregate signature created by the following algorithm:

```
List[BLSSignature] signatures
for r in records:
	for n in previousRecordNonce[r.key] + 1 .. r.nonce:
        signatures.add(consenus[r.key][n].signature)
    previousRecordNonce[r.key] = r.nonce
BLSSignature aggregate = signatures.aggregate()
```

- Every record has an unique key.
- Every record has a nonce higher than the previous record for the same key.
- Every record has a Merkle tree hash equivalent to the Merkle tree hash for the mentioned key at the mentioned nonce (as described in the Consensus documentation).
- No record archives Verifications which would cause a MeritRemoval.
- If the record archives a MeritRemoval, it only archives the MeritRemoval.
- Every Transaction verified in Verifications archived in this Block has all inputs mentioned in a past Block or in this Block.
- Every miner has an unique and valid key.
- Every miner has at least 1 Merit.
- The total of every miner’s amount equals 100.
- If there is only one miner, the BlockHeader’s miners is equivalent to the Blake2b-384 hash of the serialized miner (48-byte BLS Public Key and 1-byte amount).
- If there are multiple miners, the BlockHeader’s miners is equivalent to the Merkle tree hash of a Blake2b-384 Merkle tree where each leaf is the Blake2b-384 hash of a serialized miner.

If the Block is valid, it's added, triggering two events. The first event is the emission of newly-minted Meros and the second event is the emission of newly-mined Merit.

On Block addition, a new Epoch is created. Epochs keep track of who verified a Transaction. Every Transaction that is first verified in that Block is added to the new Epoch, along with the list of Merit Holders who verified it. If the Transaction wasn’t first verified in that Block, it’s added to the Epoch of the Block in which it was verified, as long as it has not yet been finalized. The new Epoch is added to a list of the past 5 Epochs, and the oldest Epoch is removed. This oldest Epoch has all of its Transactions which weren't verified by the majority of the live Merit removed, and is then used to calculate rewards.

In the process of calculating rewards, first every Merit Holder is assigned a score via the following code:

```
for tx in epoch:
    for verifier in epoch[tx]:
        scores[verifier] += 1

for holder in scores:
    scores[holder] *= live_merit(holder)
```

The scores are then ordered from highest to lowest. When there is a tie, the Merit Holder with the higher key is placed first. Only the top 100 scoring Merit Holders receive Mints, with the rest of the scores rolling over to the next Block. Once the top 100 scoring Merit Holders are identified, the scores are normalized to 1000 as such:

```
total = sum(scores)
for holder in scores:
    scores[holder] = scores[holder] * 1000 / total
```

If any scores happen to be 0, they are removed. If the sum of every score is less than 1000, the Merit Holder with the top score receives the difference between 1000 and the sum of the scores. A negative sigmoid which uses the Block’s difficulty for its x value produces a multiplier. Mints are then queued for each Merit Holder, in order, with an amount of `score * multiplier`. After 10 more Blocks, the mints are added to the Transactions.

After Mints are decided, every miner in the Block's miners get their specified amount of Merit. This is considered live Merit. If these new Merit Holders don't publish any Elements which get archived in a Block, for an entire Checkpoint period, not including the Checkpoint period in which they get their initial Merit, their Merit is no longer live. If a Merit Holder loses all their Merit and then regains Merit, the regained Merit counts as "initial" Merit. To restore their Merit to live, a Merit Holder must get an Element archived in a Block. This turns their Merit into Pending Merit, and their Merit will be restored to Live Merit after the next Checkpoint period. Pending Merit cannot be used on the Consensus DAG, but does contribute towards the amount of Live Merit, and can be used on Checkpoints. After 52560 Blocks, Merit dies. It cannot be restored. This sets a hard cap on the total supply of Merit at 5256000 Merit.

`BlockBody` has a variable message length; the 4-byte amount of records, the records (each with a 48-byte BLS Public Key, 4-byte nonce, and 48-byte Merkle tree hash), 1-byte amount of miners, and the miners (each with a 48-byte BLS Public Key and 1-byte amount).

### Checkpoint

Every Block where the remainder of the BlockHeader's nonce divided by 5 is 0 has a corresponding Checkpoint. The Checkpoint's signers must represent a majority of the live Merit, and the signature is the aggregate signature of every signer's signature of the Block hash. Without a Checkpoint at the proper location, a Blockchain cannot advance.

Even with Checkpoints, Blockchain reorganizations can happen if a different, valid chain has a higher cumulative difficulty. In the case the cumulative difficulties are the same, the Blockchain whose tail Block has the higher hash is the proper Blockchain.

Checkpoints are important, not just to make 51% attacks harder, but also to stop people without Merit from being able to replace a Transaction via chain reorganization and defaulting manipulation. A Transaction can be replaced by having it verified via normal operation, then wiping out all the Blocks that archive its Verifications, and then adding in Blocks which have a competing Transaction default. Once the Transaction defaults, it is finalized, even if the original Verifications are eventually archived on the Blockchain. Since every Transaction has a Checkpoint during the time it takes to default, attackers cannot use a momentary hash power surge to force a Transaction to be verified.

`Checkpoint` has a variable message length; the 48-byte Block hash, 4-byte amount of signers, every signer's 96-byte BLS Public Key, and the 96-byte aggregate signature.

### Violations in Meros

- Meros allows archived Verifications to skip over Transactions.
- Meros mints Merit before minting Meros.
- Meros doesn't check for 0-scores before minting Meros.
- Meros doesn't support dead Merit.
- Meros doesn't support chain reorganizations.
- Meros doesn't rollover rewards or use a negative sigmoid.
- Merps doesn't wait 10 Blocks to create Mints.
- Meros doesn't support the `Checkpoint` message type.
