# Merit

Merit is a blockchain used to:

- Archive Transactions and their Verifications, providing a complete overview of the network's contents.
- Coordinate the Difficulties.
- Mint Merit and Meros.

### BlockHeader Data Type

BlockHeaders exist in order to prove Block validity without syncing and verifying the entire Block, a needed feature for both highly performant networks and light clients.

BlockHeaders have the following fields:

- version: Block version.
- last: Last Block Hash.
- contents: Merkle of the included Verification Packets and Elements.
- significant: The threshold of what makes a Transaction significant.
- sketchSalt: The salt used when hashing elements for inclusion in sketches.
- sketchCheck: Merkle of the Sketch Hashes of the included Verification packets.
- miner: BLS Public Key, or miner nickname, to mint Merit to.
- time: Time this Block was mined at.
- proof: Arbitrary data used to beat the difficulty.
- signature: Miner's signature of the Block.

"contents" is an unbalanced Merkle tree which has leaves for both the Verification Packets (sorted from lowest hash to highest hash) and the Elements included in a Block. Every leaf is defined as `Blake2b(prefix + element.serialize())`, where the prefix is the same one used to create the Element's signature. The Verification Packets form the left side while the other Elements form the right side. If both sides are empty, the hash is zeroed out. If only one side is empty, it uses a zeroed out hash when forming the final hash.

"sketchCheck" is a Merkle tree which has leaves for the Sketch Hashes (sorted from lowest to highest and then hashed via `Blake2b-256`.

Meros has an on-chain nickname system for Merit Holders, where each nickname is an incremental number assigned forever. The first miner is 0, the second is 1... Referring to a miner who has already earned Merit by their key is not allowed.

A BlockHeader's signature and hash are defined as follows:

```
h1 = RandomX(header.serializeWithoutSignature())
signature = miner.sign(h1)
hash = RandomX(h1 || signature)
```

Meros uses a RandomX modified with a custom configuration. The modified configuration can be found [here](https://github.com/MerosCrypto/mc_randomx/tree/master/MerosConfiguration/configuration.h). The cache's key is updated when the Blockchain's height modulo 384 is 12. The cache's key is updated to the hash of the latest Block on the Blockchain to match height modulo 384 == 0.

### Block Data Type

Blocks mention Transactions which have had Verification Packets created.

Blocks have the following fields:

- header: Block Header.
- sketch: A PinSketch of the included Verification Packets, where each Verification Packet is included as `Blake2b-64(header.sketchSalt + packet.serialize())`.
- elements: Difficulty updates and gas price sets from Merit Holders.
- aggregate: Aggregated BLS Signature for every Verification Packet/Element this Block archives.

A Block's hash is defined as the hash of its header.

The genesis Block on the Meros mainnet Blockchain has a:

- Header version of 0.
- Header last of “MEROS_MAINNET” right padded with 0 bytes until it has a length of 32 bytes.
- Zeroed out contents in the header.
- significant of 0.
- Zeroed sketchSalt in the header.
- Zeroed out sketchCheck in the header.
- Infinite miner key in the header.
- Header time of 0.
- Header proof of 0.
- Infinite signature in the header.
- Empty packets.
- Empty elements.
- Infinite aggregate.

### Checkpoint Data Type

Checkpoints mitigate 51% attacks. By requiring the majority of Merit Holders, by weight, to agree on every 5th block (including the genesis), and not allowing the Blockchain to advance without a Checkpoint, a 51% attack would need to have not just 51% of the hash power, but 51% of the Merit. In order to obtain that much Merit, an attacker would need to sustain the attack for an entire year. Checkpoints do not stop chain reorganizations.

Checkpoints have the following fields:

- signers: List of MeritHolders (BLS Public Keys) who signed this Block.
- aggregate: BLS Signature.

### BlockHeader

When a new BlockHeader is received, it's tested for validity. The BlockHeader is valid if:

- version is 0.
- last must be equivalent to the hash of the current tail Block.
- significant is greater than 0 (exclusive) and at most 26280 (inclusive).
- miner is a valid, non-infinite, BLS Public Key if the miner is new or a valid nickname if the miner isn't new.
- The miner hasn't been proven malicious yet.
- time must be greater than the latest Block’s time.
- signature must be valid.
- hash must not overflow a 256-bit number when multiplied by the difficulty.

If the BlockHeader is valid, full nodes sync the rest of the Block via a `BlockBodyRequest`.

`BlockHeader` has a message length of either 165 or 259 bytes; the 4-byte version, 32-byte last hash, 32-byte contents hash, 2-byte significant, 4-byte sketchSalt, 32-byte sketchCheck hash, 1-byte of "\1" if the miner is new or "\0" if not, 2-byte miner nickname if the last byte is "\0" or 96-byte miner BLS Public Key if the last byte is "\1", 4-byte time, 4-byte proof, and 48-byte signature.

### BlockBody

When a new BlockBody is received, a full Block can be formed using the BlockHeader. The Block is valid if:

- The header is valid.
- contents is the result of a properly constructed Merkle tree.
- The Block's included Verification Packets don't collide with the specified sketch salt.
- sketchCheck is the result of a properly constructed Merkle tree.
- Every Verification Packet is for an unique Transaction.
- Every Verification Packet only contains new Verifications.
- Every Verification Packet's Merit is greater than significant, where Merit is the current Merit balance ignoring its status of Unlocked/Locked/Pending.
- Every Transaction's predecessors have Verification Packets either archived or in this Block.
- Every Transaction either has yet to enter Epochs or is in Epochs.
- Every Transaction doesn't compete with, or have parents which competed with and lost, finalized Transactions.
- Only new and unique Elements are archived.
- No SendDifficulty or DataDifficulty skips a nonce for their Merit Holder. That said, the Block may skip a nonce if the skipped nonce is present later in the Block.
- The aggregate signature is formed with the following algorithm:

```
List[BLSSignature] signatures
for tx in transactions:
  signatures.add(packets[tx])
for elem in elements:
  signatures.add(element.signature)
BLSSignature aggregate = infinity
if signatures.length != 0
  aggregate = signatures.aggregate()
```

If the Block is valid, it's added, triggering four events. The first event is the addition of all included VerificationPackets and Elements, as well as the accompanying removal of all Merit by any malicious holders (as proven by the included Verifications/Elements). The second event is the emission of newly-minted Meros. The third event is the emission of newly-mined Merit. Any malicious Merit Holders are incapable from gaining newly-mined Merit from this Block. The fourth event is the automated creation of a Data Transaction.

On Block addition, a new Epoch is created. Epochs keep track of who verified a Transaction. Every Transaction that is first verified in that Block is added to the new Epoch. If a new Transaction competes with an existing Transaction, all competitors (and competitors of competitors) are brought up into the new Epoch. If any descendants of the moved transactions now have an earlier Epoch than their parents, they too are brought up. Every Transaction in Epochs is updated with the list of Merit Holders who verified it. The new Epoch is added to a list of the past 5 Epochs, and the oldest Epoch is removed. This oldest Epoch has all of its Transactions which weren't verified by the majority of the Unlocked Merit removed, and is then used to calculate rewards.

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

After Mints are decided, the Block's miner gets 1 Merit. If this is the miner's initial Merit, this is Unlocked Merit. If a Merit Holder loses all their Merit and then regains Merit, the regained Merit counts as initial Merit. If a Merit Holder, whose Merit is unlocked, doesn't publish any Elements which get archived for an entire Checkpoint period, not including the Checkpoint period in which they gain their initial Merit, their Merit becomes locked. To restore their Merit to unlocked, a Merit Holder must get an Element archived in a Block. This turns their Merit into Pending Merit, and their Merit will be restored to Unlocked Merit after the next Checkpoint period. Pending Merit cannot be used on the Consensus DAG, but does contribute towards the amount of Unlocked Merit, and can be used on Checkpoints. After 52560 Blocks, Merit dies. It cannot be restored. This sets a hard cap on the total supply of Merit at 52560 Merit.

The created Data happens after Block addition the rest of Block addition is completed, using an input of the genesis hash and the new Block's hash as its data. It gets no special status in how its verified/placed into Epochs/finalized. That said, it cannot compete with other Datas created from Block addition, and has no value in being broadcasted, as every node will create a Data with the same hash. The purpose of this is to make sure Merit Holders always have something to verify, which is important for two reasons:

1) Meros will always be minted after the first Epoch closes, ensuring a steady stream of fresh issuance, without just paying out to whoever has the most Merit.
2) If there's no Transactions for an hour, every Merit Holder won't lock their own Merit out, thanks to this Data. If there were no Transactions, and every Merit Holder did lock their own Merit out, instant verification would be halted until an hour after the next Transaction appears. The Checkpoint would also be impossible to verify, requiring a new last Block containing a verification for the chain to advance.

`BlockBody` has a variable message length; the 32-byte contents Merkle's left side hash, 4-byte sketch capacity, variable length sketch, 4-byte amount of Elements, Elements (each a different length depending on its type, with a 1-byte prefix of its type (same prefix used in the contents Merkle)), and the 48-byte signature.

### Checkpoint

Every Block whose height modulo 5 is 0 has a corresponding Checkpoint. The Checkpoint's signers must represent a majority of the Unlocked and Pending Merit, where the signature is created by signing the Block hash. Without a Checkpoint, a Blockchain cannot advance.

Even with Checkpoints, Blockchain reorganizations can happen if a different, valid chain has a higher cumulative difficulty. In the case the cumulative difficulties are the same, the Blockchain whose tail Block has the lower hash is the proper Blockchain.

Checkpoints are important, not just to make 51% attacks harder, but also to stop people without Merit from being able to replace a Transaction via chain reorganization and defaulting manipulation. A Transaction can be replaced by having it verified via normal operation, then wiping out all the Blocks that archive its Verifications, and then adding in Blocks which have a competing Transaction default. Once the Transaction defaults, it is finalized, even if the original Verifications are eventually archived on the Blockchain. Since every Transaction has a Checkpoint during the time it takes to default, attackers cannot use a momentary hash power surge to force a Transaction to be verified.

`Checkpoint` has a variable message length; the 32-byte Block hash, 2-byte amount of Merit Holders, the Merit Holders (each represented by their 2-byte nickname), and the 48-byte aggregate signature.

### Violations in Meros

- Meros puts competitors in the first archived TX's Epoch, instead of bringing that TX forward.
- Meros doesn't rollover rewards or use a negative sigmoid.
- Meros doesn't wait 10 Blocks to create Mints.

- Meros doesn't support the `Checkpoint` message type.
