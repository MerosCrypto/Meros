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
- contents: Merkle of included Transactions, as well as the included updates to the Difficulties/GasPrice.
- verifiers: Merkle of who verified each Transaction mentioned in this Block.
- miner: BLS Public Key, or miner nickname, to mint Merit to.
- time: Time this Block was mined at.
- proof: Arbitrary data used to beat the difficulty.
- signature: Miner's signature of the Block.

Meros has an on-chain nickname system for Merit Holders, where each nickname is an incremental number assigned forever. The first miner is 0, the second is 1... Referring to a miner who has already earned Merit by their key is not allowed.

The "contents" has leaves for both Transactions and the Elements included in a Block. Each leaf representing a Transaction is simply defined as the Transaction hash. Each leaf representing an Element is defined as `Blake2b-384(prefix + element.serialize())`, where the prefix is the same one used to create the Element's signature.

The "verifiers" has one leaf per Transaction, where the n-th leaf is of the Verification Packet for the n-th Transaction, defined as `Blake2b(packet.serialize())`.

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
- significant: The threshold of what makes a Transaction significant. 10 means anything which has more than 10 (inclusive) new Merit to archive.
- sketchSalt: The salt used when hashing elements for inclusion in sketches.
- transactions: A PinSketch of the included Transactions, with a capacity of at least `transactions.length div 5 + 1` and at most `transactions.length div 5 + 11`, where each Transaction hash is included as `Blake2b-64(sketchSalt + hash)`. If there's no transactions in the Block, a capacity of 0 is valid. If a Transaction's 8-byte hash has a collision with another Transaction's, the sketchSalt must be changed and the sketch regenerated until there is no collision.
- packets: A PinSketch of the included Verification Packets, with a capacity matching transactions, where each Verification Packet is included as `Blake2b-64(sketchSalt + packet.serialize())`. If a Verification Packet's 8-byte hash has a collision with another Verification Packet's, the sketchSalt must be changed and the sketch regenerated until there is no collision.
- elements: Difficulty updates and gas price sets from Merit Holders.
- aggregate: Aggregated BLS Signature for every Verification Packet/Element this Block archives.

A Block's hash is defined as the hash of its header.

The genesis Block on the Meros mainnet Blockchain has a:
- Header version of 0,
- Header last of “MEROS_MAINNET” left padded with 0 bytes until it has a length of 48 bytes.
- Zeroed out contents in the header.
- Zeroed out verifiers in the header.
- Zeroed out miner key in the header.
- Header time of 0.
- Header proof of 0.
- Zeroed out signature in the header.
- significant of 0.
- sketchSalt of 0.
- Empty transactions.
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

`BlockHeader` has a message length of either 255 or 301 bytes; the 4-byte version, 48-byte last hash, 48-byte contents hash, 48-byte verifiers hash, 1-byte of "\1" if the miner is new or "\0" if not, 2-byte miner nickname if the last byte is "\0" or 48-byte miner BLS Public Key if the last byte is "\1", 4-byte time, 4-byte proof, and 96-byte signature.

### BlockBody

When a new BlockBody is received, a full Block can be formed using the BlockHeader. The Block is valid if:

- The header is valid.
- contents is the result of a properly constructed Merkle tree. It should be noted the tree used to form contents must include automatically included predecessors.
- verifiers is the result of a properly constructed Merkle tree.
- significant is between 0 (exclusive) and 26280 (inclusive).
- Every Transaction is unique.
- Every Transaction has a Verification Packet involving Merit Holders not previously archived on the Blockchain.
- Every Transaction's Verification Packet's newly archived Merit Holders' Merit sums to be greater than significant.
- Every Transaction's predecessors have Verification Packets.
- Every Transaction's predecessors, if they have yet to be mentioned on the Blockchain, are not mentioned in this BlockBody.
- Every Transaction either has yet to enter Epochs or is in Epochs.
- Every Transaction doesn't compete with, or have parents which competed with and lost, Transactions archived 5 Blocks before the last Checkpoint.
- Each sketch is properly constructed from the data used to construct their respective Merkle.
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

When a Transaction is first mentioned on the Blockchain, it automatically includes all predecessors which have yet to be mentioned. The predecessors are locally inserted into the Transaction list after the mentioned Transaction, using the following algorithm for the ordering:

```
List[Hash] toAppend
for input in tx:
    if input.hash not in mentioned:
        toAppend.add(input.hash)

int i = 0
while i < toAppend.length:
    for input in transactions[toAppend[i]]:
        if input.hash not in mentioned:
            toAppend.add(input.hash)
    i++
```

If the Block is valid, it's added, triggering two events. The first event is the emission of newly-minted Meros and the second event is the emission of newly-mined Merit.

On Block addition, a new Epoch is created. Epochs keep track of who verified a Transaction. Every Transaction that is first verified in that Block is added to the new Epoch. If a new Transaction competes with an existing Transaction, all competitors (and competitors of competitors) and children (and children of competitors) are brought up into the new Epoch. Every Transaction in Epochs is updated with the list of Merit Holders who verified it. The new Epoch is added to a list of the past 5 Epochs, and the oldest Epoch is removed. This oldest Epoch has all of its Transactions which weren't verified by the majority of the live Merit removed, and is then used to calculate rewards.

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

After Mints are decided, the Block's miner gets 1 Merit. This is considered live Merit. If these new Merit Holders don't publish any Elements which get archived in a Block, for an entire Checkpoint period, not including the Checkpoint period in which they get their initial Merit, their Merit is no longer live. If a Merit Holder loses all their Merit and then regains Merit, the regained Merit counts as "initial" Merit. To restore their Merit to live, a Merit Holder must get an Element archived in a Block. This turns their Merit into Pending Merit, and their Merit will be restored to Live Merit after the next Checkpoint period. Pending Merit cannot be used on the Consensus DAG, but does contribute towards the amount of Live Merit, and can be used on Checkpoints. After 52560 Blocks, Merit dies. It cannot be restored. This sets a hard cap on the total supply of Merit at 52560 Merit.

`BlockBody` has a variable message length; the 4-byte significant, 4-byte sketchSalt, 4-byte Transactions sketch capacity, variable length Transactions sketch, variable length Packets sketch, 4-byte amount of Elements, Elements (each a different length depending on its type), and the 96-byte signature.

### Checkpoint

Every Block where the remainder of the BlockHeader's nonce divided by 5 is 0 has a corresponding Checkpoint. The Checkpoint's signers must represent a majority of the live Merit, and the signature is the aggregate signature of every signer's signature of the Block hash. Without a Checkpoint at the proper location, a Blockchain cannot advance.

Even with Checkpoints, Blockchain reorganizations can happen if a different, valid chain has a higher cumulative difficulty. In the case the cumulative difficulties are the same, the Blockchain whose tail Block has the higher hash is the proper Blockchain.

Checkpoints are important, not just to make 51% attacks harder, but also to stop people without Merit from being able to replace a Transaction via chain reorganization and defaulting manipulation. A Transaction can be replaced by having it verified via normal operation, then wiping out all the Blocks that archive its Verifications, and then adding in Blocks which have a competing Transaction default. Once the Transaction defaults, it is finalized, even if the original Verifications are eventually archived on the Blockchain. Since every Transaction has a Checkpoint during the time it takes to default, attackers cannot use a momentary hash power surge to force a Transaction to be verified.

`Checkpoint` has a variable message length; the 48-byte Block hash, 4-byte amount of signers, every signer's 96-byte BLS Public Key, and the 96-byte aggregate signature.

### Violations in Meros

- Meros doesn't check that newly archived Merit Holders' Merit is greater than significant for every Transaction.
- Meros doesn't check Sketches have valid capacity fields.
- Meros allows mentioning previously unmentioned predecessors with their successor.
- Meros allows mentioning Transactions out of Epochs/Transactions which compete with old Transactions. This behavior should be fixed on the Transactions DAG, not on the Blockchain.
- Meros doesn't automatically include unmentioned predecessors after their successor in BlockBody's local Transactions list.

- Meros mints Merit before minting Meros.
- Meros doesn't support dead Merit.

- Meros puts competitors in the first archived TX's Epoch, instead of bringing that TX forward.
- Meros doesn't check for 0-scores before minting Meros.
- Meros doesn't rollover rewards or use a negative sigmoid.
- Merps doesn't wait 10 Blocks to create Mints.

- Meros doesn't support chain reorganizations.
- Meros doesn't support the `Checkpoint` message type.
