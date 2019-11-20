# Merit

Merit is a blockchain used to:

- Archive Transactions and their Verifications, providing a complete overview of the network's contents.
- Coordinate the Difficulties and Gas Price.
- Mint Merit and Meros.

### BlockHeader Data Type

BlockHeaders exist in order to prove Block validity without syncing and verifying the entire Block, a needed feature for both highly performant networks and light clients.

BlockHeaders have the following fields:

- version: Block version.
- last: Last Block Hash.
- contents: Merkle of included Sketch Hashes and Elements.
- significant: The threshold of what makes a Transaction significant.
- sketchSalt: The salt used when hashing elements for inclusion in sketches.
- miner: BLS Public Key, or miner nickname, to mint Merit to.
- time: Time this Block was mined at.
- proof: Arbitrary data used to beat the difficulty.
- signature: Miner's signature of the Block.

Meros has an on-chain nickname system for Merit Holders, where each nickname is an incremental number assigned forever. The first miner is 0, the second is 1... Referring to a miner who has already earned Merit by their key is not allowed.

"contents" is an unbalanced Merkle tree where the left side has leaves for the Sketch Hashes (sorted from highest to lowest and then hashed via `Blake2b-384`) and the right side has leaves for the Elements included in a Block (defined as `Blake2b-384(prefix + element.serialize())`). If there's no packets in the Block, the left side has a zeroed out hash. If there's no elements in the Block, the right side has a zeroed out hash. If there's no packets or elements in the Block, the entire merkle has a zeroed out hash.

A BlockHeader's signature and hash are defined as follows:

```
h1 = Argon2d(
    iterations = 1,
    memory = 65536,
    parallelism = 1
    data = header.serializeWithoutProofOrSignature(),
    salt = proof left padded to be 8 bytes long
)

signature = miner.sign(h1)
hash = Argon2d(
    iterations = 1,
    memory = 65536,
    parallelism = 1
    data = h1,
    salt = signature
)
```

### Block Data Type

Blocks mention Transactions which have had Verification Packets created.

Blocks have the following fields:

- header: Block Header.
- sketch: A PinSketch of the included Verification Packets, where each Verification Packet is included as `Blake2b-64(header.sketchSalt + packet.serialize())`.
- elements: Difficulty updates and gas price sets from Merit Holders.
- aggregate: Aggregated BLS Signature for every Verification Packet/Element this Block archives.

A Block's hash is defined as the hash of its header.

The genesis Block on the Meros mainnet Blockchain has a:
- Header version of 0,
- Header last of “MEROS_MAINNET” left padded with 0 bytes until it has a length of 48 bytes.
- Zeroed out contents in the header.
- significant of 0.
- Zeroed sketchSalt in the header.
- Zeroed out miner key in the header.
- Header time of 0.
- Header proof of 0.
- Zeroed out signature in the header.
- Empty packets.
- Empty elements.
- aggregate is zeroed out.

### Checkpoint Data Type

Checkpoints mitigate 51% attacks. By requiring the majority of Merit Holders, by weight, to agree on every 5th block, and not allowing the Blockchain to advance without a Checkpoint, a 51% attack would need to have not just 51% of the hash power, but 51% of the Merit. In order to obtain that much Merit, an attacker would need to sustain the attack for an entire year. Checkpoints do not stop chain reorganizations.

Checkpoints have the following fields:

- signers: List of MeritHolders (BLS Public Keys) who signed this Block.
- aggregate: BLS Signature.

### BlockHeader

When a new BlockHeader is received, it's tested for validity. The BlockHeader is valid if:

- version is 0.
- last must be equivalent to the hash of the current tail Block.
- miner is a valid BLS Public Key if the miner is new or a valid nickname if the miner isn't new.
- time must be greater than the current Block’s time.
- time must be less than 2 minutes into the future.
- hash must not be less than the current difficulty.

If the BlockHeader is valid, full nodes sync the rest of the Block via a `BlockBodyRequest`.

`BlockHeader` has a message length of either 213 or 261 bytes; the 4-byte version, 48-byte last hash, 48-byte contents hash, 2-byte significant, 4-byte sketchSalt, 1-byte of "\1" if the miner is new or "\0" if not, 2-byte miner nickname if the last byte is "\0" or 48-byte miner BLS Public Key if the last byte is "\1", 4-byte time, 4-byte proof, and 96-byte signature.

### BlockBody

When a new BlockBody is received, a full Block can be formed using the BlockHeader. The Block is valid if:

- The header is valid.
- contents is the result of a properly constructed Merkle tree.
- significant is greater than 0 and at most 26280 (inclusive).
- capacity is at least `packets.length div 5 + 1` and at most `packets.length div 5 + 11`.
- The Block's included Verification Packets don't collide with the specified sketch salt.
- Every Verification Packet is for an unique Transaction.
- Every Verification Packet only contains new Verifications.
- Every Verification Packet's Merit is greater than significant.
- Every Transaction's predecessors have Verification Packets either archived or in this Block.
- Every Transaction either has yet to enter Epochs or is in Epochs.
- Every Transaction doesn't compete with, or have parents which competed with and lost, Transactions archived 5 Blocks before the last Checkpoint.
- The sketch is properly constructed from the same data used to construct the Merkle.
- Only new Elements are archived.
- No SendDifficulty, DataDifficulty, or GasPrice skips a nonce for their Merit Holder.
- Every Element is valid and doesn't cause a MeritRemoval when combined with another Element either already on the Blockchain or in the same Block.
- The aggregate signature is formed with the following algorithm:

```
List[BLSSignature] signatures
for tx in transactions:
    signatures.add(packets[tx])
for elem in elements:
    signatures.add(element.signature)
BLSSignature aggregate = signatures.aggregate()
```

If the Block is valid, it's added, triggering two events. The first event is the emission of newly-minted Meros and the second event is the emission of newly-mined Merit.

On Block addition, a new Epoch is created. Epochs keep track of who verified a Transaction. Every Transaction that is first verified in that Block is added to the new Epoch. If a new Transaction competes with an existing Transaction, all competitors (and competitors of competitors) and children (and children of competitors) are brought up into the new Epoch. Every Transaction in Epochs is updated with the list of Merit Holders who verified it. The new Epoch is added to a list of the past 5 Epochs, and the oldest Epoch is removed. This oldest Epoch has all of its Transactions which weren't verified by the majority of the Unlocked Merit removed, and is then used to calculate rewards.

In the process of calculating rewards, first every Merit Holder is assigned a score via the following code:

```
for tx in epoch:
    for verifier in epoch[tx]:
        scores[verifier] += 1

for holder in scores:
    scores[holder] *= unlocked_merit(holder)
```

The scores are then ordered from highest to lowest. When there is a tie, the Merit Holder with the lower nickname is placed first. Only the top 100 scoring Merit Holders receive Mints, with the rest of the scores rolling over to the next Block. Once the top 100 scoring Merit Holders are identified, the scores are normalized to 1000 as such:

```
total = sum(scores)
for holder in scores:
    scores[holder] = scores[holder] * 1000 / total
```

If any scores happen to be 0, they are removed. If the sum of every score is less than 1000, the Merit Holder with the top score receives the difference between 1000 and the sum of the scores. A negative sigmoid which uses the Block’s difficulty for its x value produces a multiplier. Mints are then queued for each Merit Holder, in order, with an amount of `score * multiplier`. After 10 more Blocks, the mints are added to the Transactions.

After Mints are decided, the Block's miner gets 1 Merit. If this the miner's initial Merit, this is Unlocked Merit. If a Merit Holder loses all their Merit and then regains Merit, the regained Merit counts as "initial" Merit. If the new Merit Holder doesn't publish any Elements which get archived in a Block, for an entire Checkpoint period, not including the Checkpoint period in which they get their initial Merit, their Merit is locked. To restore their Merit to unlocked, a Merit Holder must get an Element archived in a Block. This turns their Merit into Pending Merit, and their Merit will be restored to Unlocked Merit after the next Checkpoint period. Pending Merit cannot be used on the Consensus DAG, but does contribute towards the amount of Unlocked Merit, and can be used on Checkpoints. After 52560 Blocks, Merit dies. It cannot be restored. This sets a hard cap on the total supply of Merit at 52560 Merit.

`BlockBody` has a variable message length; the 4-byte sketch capacity, variable length sketch, 4-byte amount of Elements, Elements (each a different length depending on its type), and the 96-byte signature.

### Checkpoint

Every Block where the remainder of the BlockHeader's nonce divided by 5 is 0 has a corresponding Checkpoint. The Checkpoint's signers must represent a majority of the Unlocked Merit and Pending Merit, and the signature is the aggregate signature of every signer's signature of the Block hash. Without a Checkpoint at the proper location, a Blockchain cannot advance.

Even with Checkpoints, Blockchain reorganizations can happen if a different, valid chain has a higher cumulative difficulty. In the case the cumulative difficulties are the same, the Blockchain whose tail Block has the higher hash is the proper Blockchain.

Checkpoints are important, not just to make 51% attacks harder, but also to stop people without Merit from being able to replace a Transaction via chain reorganization and defaulting manipulation. A Transaction can be replaced by having it verified via normal operation, then wiping out all the Blocks that archive its Verifications, and then adding in Blocks which have a competing Transaction default. Once the Transaction defaults, it is finalized, even if the original Verifications are eventually archived on the Blockchain. Since every Transaction has a Checkpoint during the time it takes to default, attackers cannot use a momentary hash power surge to force a Transaction to be verified.

`Checkpoint` has a variable message length; the 48-byte Block hash, 4-byte amount of signers, every signer's 96-byte BLS Public Key, and the 96-byte aggregate signature.

### Violations in Meros

- Meros doesn't check that BlockHeader's have valid significant fields.
- Meros doesn't check BlockBody's have valid capacity fields.
- Meros allows Verification Packets which contain archived Verifications.
- Meros doesn't check that Blocks Verification Packets' Merits are greater than significant.
- Meros doesn't check that every predecessor has an archived Verification Packet.
- Meros allows mentioning Transactions out of Epochs/Transactions which compete with old Transactions. This behavior should be fixed on the Transactions DAG, not on the Blockchain.
- Meros doesn't check that Block's Elements are new and have proper nonces.
- Meros doesn't check that Block's Elements don't cause a MeritRemoval.

- Meros mints Merit before minting Meros.
- Meros doesn't support dead Merit.

- Meros puts competitors in the first archived TX's Epoch, instead of bringing that TX forward.
- Meros doesn't check for 0-scores before minting Meros.
- Meros doesn't rollover rewards or use a negative sigmoid.
- Merps doesn't wait 10 Blocks to create Mints.

- Meros doesn't support chain reorganizations.
- Meros doesn't support the `Checkpoint` message type.
