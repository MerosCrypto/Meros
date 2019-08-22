# Consensus

"Consensus" is a DAG, specifically a Block Lattice, containing Verifications, MeritRemovals, Difficulty Updates, and Gas Price sets. The reason it's called Consensus is because even though the Blockchain has the final say, the Blockchain solely distributes Merit (used to weight Consensus), archives Elements from the Consensus layer, and mints Meris.

"Consensus" is made up of MeritHolders (Merkle tree + Element array), indexed by BLS Public Keys. Only the key pair behind a MeritHolder can add an Element to it, except in the case of a MeritRemoval. MeritHolders are trusted to always have one Element per nonce. If a MeritHolder ever has multiple Elements per nonce, they lose all their Merit.

Every Element has the following fields:

- holder: BLS Public Key of the Merit Holder who created the Element.
- nonce: Index of the Element on the MeritHolder. Starts at 0 and increments by 1 for every added Element.

The Element sub-types are as follows:

- Verification
- SendDifficulty
- DataDifficulty
- GasPrice
- MeritRemoval

When a new Element is received via a `SignedVerification`, `SignedSendDifficulty`, `SignedDataDifficulty`, `SignedGasPrice`, or `SignedMeritRemoval` message, it's added to the holder's MeritHolder, as long as the holder has Merit, the signature is correct, and any other checks imposed by the sub-type pass. Elements don't have hashes, so the signature is produced by signing the serialized version with a prefix.

The `Verification`, `SendDifficulty`, `DataDifficulty`, `GasPrice`, and `MeritRemoval` messages are only used when syncing, and their signature data is contained in a Block's aggregate signature, as described in the Merit documentation.

The Merkle tree each MeritHolder has uses Blake2b-384 as a hash algorithm and consists of the MeritHolder's unarchived Elements, as described in the Merit documentation. Each leaf is the Blake2b-384 hash of a serialized Element with the prefix used to create the signature. If there is only one leaf in the tree, the tree's hash is the leaf's hash.

### Verification

A Verification is a MeritHolder staking their Merit behind a Transaction and approving it. If a Transaction has `LIVE_MERIT / 2 + 1` Merit staked behind it at the end of its Epoch, it is verified. Live Merit is described in the Merit documentation, and the Live Merit value used is what it will be at the end of the Transaction's Epoch. It should be noted Meros considers a Transaction verified as soon as it crosses its threshold, which uses a different formula than the protocol. If a Verification isn't archived by the end of these 6 Blocks, it should not be counted towards the Transaction's final Merit. Transactions can also be verified through a process known as "defaulting". Once an input is used in a Transaction mentioned in a Block, if five more Blocks pass without a Transaction using that input obtaining the needed Merit, the Transaction with the most Merit which uses that input, which is also mentioned in a Block, or if there's a tie, the Transaction with the higher hash, becomes verified after the next Checkpoint.

It is possible for a MeritHolder who votes on competing Transactions using the same input to cause both to become verified. This is eventually resolved, as described below in the MeritRemoval section, yet raises the risk of reverting a Transaction's verification. There are multiple ways to prevent this and handle it in the moment, yet the Meros protocol is indifferent, as long as all nodes resolve it and maintain consensus. If Meros detects multiple Transactions sharing an input, it will wait for a Transaction to default, not allowing for verification via Verifications alone.

They have the following fields:

- hash: Hash of the Transaction verified.

Verifications can only be of parsable Transactions, even ones with an invalid signature. Verifications with unknown hashes are invalid, yet still usable as causes for a MeritRemoval.

`Verification` has a message length of 100 bytes; the 48-byte holder, the 4-byte nonce, and the 48-byte hash. The signature is produced with a prefix of "\0".

### SendDifficulty

A SendDifficulty is a MeritHolder voting to update the difficulty of the spam filter applied to Sends. Every MeritHolder gets one vote per 10,000 Merit. Every MeritHolder can specify a singular difficulty which is voted on by all their votes. The difficulty that is the median of all votes is chosen.

The 10,000 Merit limit creates a maximum of 525 votes. The multiple votes per MeritHolder means MeritHolders with more Merit get more power. The median means that if the difficulty is 10, and a MeritHolder wants it to be 9, they can't game the system by voting for a radically lower difficulty, like they could with an average.

When the difficulty is lowered, there's a chance Transactions based on the new difficulty may be rejected by nodes still using the old difficulty. When the difficulty is raised, there's a chance Transactions based on the old difficulty may still be accepted by nodes who have yet to update. The first scenario adds a delay to the system, and adding a Block will catch all the nodes up. The second scenario risks rewinding Transactions. Therefore, if a Transaction doesn't beat the spam filter, but does still get the needed Verifications to become verified, it's still valid.

In the case no SendDifficulties have been added to the Consensus yet, the spam filter defaults to using a difficulty of 48 "AA" bytes.

They have the following fields:

- difficulty: 384-bit number that should be the difficulty for the Sends' spam filter.

`SendDifficulty` has a message length of 100 bytes; the 48-byte holder, the 4-byte nonce, and the 48-byte difficulty. The signature is produced with a prefix of "\1".

### DataDifficulty

A DataDifficulty is a MeritHolder voting to update the difficulty of the spam filter applied to Datas. The way this difficulty is determined is the exact same as the way the Sends' spam filter difficulty is determined. That said, the difficulty has a lower bound of `000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000`, where any vote for something lower is counted as a vote for this lower bound.

In the case no DataDifficulties have been added to the Consensus yet, the spam filter defaults to using a difficulty of 48 "CC" bytes.

They have the following fields:

- difficulty: 384-bit number that should be the difficulty for the Datas' spam filter.

`DataDifficulty` has a message length of 100 bytes; the 48-byte holder, the 4-byte nonce, and the 48-byte difficulty. The signature is produced with a prefix of "\2".

### GasPrice

Unlock Transactions execute MerosScript. Each MerosScript operation has a different amount of "gas" required to be executed. In order to reward MeritHolders for executing MerosScipt, the sender of the Unlock must pay `gasPrice * gas` in Meros.

A GasPrice is a MeritHolder voting to update the gasPrice variable. The way the gasPrice is determined is the exact same as the way the spam filters determine their difficulty except that gas price updates only take effect once archived in a Block.

They have the following fields:

- price: Price in Meri a unit of gas should cost.

`GasPrice` has a message length of 56 bytes; the 48-byte holder, the 4-byte nonce, and the 4-byte price (setting a max price of 4.29 Meros per unit of gas). The signature is produced with a prefix of "\3".

### MeritRemoval

MeritRemovals aren't created on their own. When a MeritHolder creates two Elements with the same nonce, or two Verifications at different nonces which verify competing Transactions, nodes add a MeritRemoval to the MeritHolder. This MeritRemoval is added right after the archived Elements. All unarchived Verifications are struck null and void, with all votes (SendDifficulty, DataDifficulty, and GasPrice) being completely removed from consideration. Pending Elements can be safely pruned once the MeritRemoval is included in a Block.

The creation of a MeritRemoval causes the MeritHolder's Merit to no longer be usable. Once the MeritRemoval is in a Block, the Merit no longer contributes to the amount of 'live' Merit, in order to not raise the percentage of Merit needed to verify a transaction. This is further described in the Merit documentation. Merit Holders are ineligible for rewards using removed Merit. Merit Holders may regain Merit, yet if the Block which archives their Merit Removal gives them Merit, it is also removed.

If multiple MeritRemovals are triggered, the first one will have already reverted unarchived actions and stripped the MeritHolder of their Merit. The remaining work becomes achieving consensus on what Elements to name as the MeritRemoval's cause. This is achieved when the next Block is mined, and the next Block's miner decides what Elements are the MeritRemoval's cause for the entire network.

MeritRemovals have the following fields:

- partial:  Whether or not the first Element is already archived on the Blockchain.
- element1: The first Element.
- element2: The second Element.

`MeritRemoval` isn't needed per se. Instead, nodes could just broadcast both causes. The unified message ensures nodes get both causes and trigger a MeritRemoval on their end. It has a variable message length; the 48-byte holder, 1-byte of "\1" if partial or "\0" if not, the 1-byte sign prefix for the first Element, the serialized version of the first Element without the holder, the 1-byte sign prefix for the Element, and the serialized version of the second Element without the holder. The nonce is not serialized as its nonce is dependent on when it's archived. Even though MeritRemovals are not signed, they use a prefix of "\4" for merkle creation.

### SignedVerification, SignedSendDifficulty, SignedDataDifficulty, SignedGasPrice, and SignedMeritRemoval

Every "Signed" object is the same as their non-"Signed" counterpart, except they don't rely on a Block's aggregate signature and have the extra field of:

- signature: BLS Signature of the object. In the case of a SignedMeritRemoval, this is the aggregate signature of element1 and element2. If one Element has already been archived in a Block, the signature is the second Element's signature.

Their message lengths are their non-"Signed" message length plus 96 bytes; the 96-byte signature which is appended to the end of the serialized non-"Signed" version.

### Violations in Meros

- Meros calculates thresholds as `LIVE_MERIT / 2 + 601`. This drifts to cause higher thresholds as the Transaction's lifespan progresses. It should be `LIVE_MERIT_AT_END_OF_EPOCH / 2 + 601`.
- Meros doesn't produce a final Merit tally of Transaction weights. This can lead to false positives on what's verified, causing forks via child Transactions and reward calculations.
- Meros doesn't support defaulting.
- Meros doesn't track if two Transactions spend the same input (which should disable instant verification).
- Meros doesn't support `SignedSendDifficulty` or `SendDifficulty`.
- Meros doesn't support `SignedDataDifficulty` or `DataDifficulty`.
- Meros doesn't support `SignedGasPrice` or `GasPrice`.
- Meros doesn't support MeritRemovals caused by verifying competing Transactions.
