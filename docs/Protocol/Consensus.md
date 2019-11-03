# Consensus

This document defines and describes Consensus Elements, which come in the forms of Verifications, Merit Removals, Difficulty Updates, and Gas Price sets. Every Element has a creator, which is the 2-byte nickname of the Merit Holder who created it. When a new Element is received via a `SignedVerification`, `SignedSendDifficulty`, `SignedDataDifficulty`, or `SignedMeritRemoval` message, node behavior should be to immediately perform the protocol dictated action, as long as the Element is valid. Gas Price Elements can only have their actions applied once archived in a Block. `SignedGasPrice` exists solely to give miners other than the sender the ability to archive the Element as well

Elements do not have hashes, so their signatures are produced by signing their serialization, without the holder, and with a prefix unique to each type of Element.

### Verification

A Verification is a Merit Holder staking their Merit behind a Transaction and approving it. If a Transaction has `LIVE_MERIT / 2 + 1` Merit staked behind it at the end of its Epoch, it is verified. Live Merit is described in the Merit documentation, and the Live Merit value used is what it will be at the end of the Transaction's Epoch. It should be noted Meros considers a Transaction verified as soon as it crosses its threshold, which uses a different formula than the protocol. If a Verification isn't archived by the end of these 6 Blocks, it should not be counted towards the Transaction's final Merit. Transactions can also be verified through a process known as "defaulting". Once an input is used in a Transaction mentioned in a Block, if five more Blocks pass without a Transaction using that input obtaining the needed Merit, the Transaction with the most Merit which uses that input, which is also mentioned in a Block, or if there's a tie, the Transaction with the higher hash, becomes verified after the next Checkpoint.

It is possible for a Merit Holder who votes on competing Transactions using the same input to cause both to become verified. This is eventually resolved, as described below in the `MeritRemoval` section, yet raises the risk of reverting a Transaction's verification. There are multiple ways to prevent this and handle it in the moment, yet the Meros protocol is indifferent, as long as all nodes resolve it and maintain consensus. If Meros detects multiple Transactions sharing an input, it will wait for a Transaction to default, not allowing for verification via Verifications alone. Meros also requires an 80% threshold to be crossed before marking a Transaction as verified, not a 50.1% threshold.

They have the following fields:

- hash: Hash of the Transaction verified.

Verifications can only be of valid Transactions, meaning Transactions which have been mentioned on the chain or still can be mentioned in a future Block. The Transaction does NOT have to beat any spam filter.

`Verification` has a message length of 50 bytes; the 2-byte creator's nickname, and the 48-byte hash. The signature is produced with a prefix of "\0".

### VerificationPacket

A Verification packet is a group of Verifications belonging to a single Transaction. They use less bandwidth than individual Verifications and are faster to handle in the moment as their signed version uses a single signature for every message.

`VerificationPacket` has a variable message length; the 1-byte amount of Verifications, the verifiers (each represented by their 2-byte nickname, in ascending order), and the 48-byte hash. Even though VerificationPackets are not directly signed, they use a prefix of "\1" inside a Block Header's content merkle.

### SendDifficulty

A SendDifficulty is a Merit Holder voting to update the difficulty of the spam filter applied to Sends. Every Merit Holder gets one vote per 50 Merit. Every Merit Holder can specify a singular difficulty which is voted on by all their votes. The difficulty that is the median of all votes is chosen. The 50 Merit per vote creates a maximum of 1051 votes. The multiple votes per Merit Holder stops sybil attacks, correctly weighing against the Merit Holder's power. The choice of median over mean stops Merit Holders from being incentivized to vote far from their target in order to have more power.

When the difficulty is lowered, there's a chance Transactions based on the new difficulty may be rejected by nodes still using the old difficulty. When the difficulty is raised, there's a chance Transactions based on the old difficulty may still be accepted by nodes who have yet to update. The first scenario adds a delay to the system, and adding a Block will catch all the nodes up. The second scenario risks rewinding Transactions. Therefore, if a Transaction doesn't beat the spam filter, but does still get the needed Verifications to become verified, it's still valid. This makes the difficulty a coordinated guideline, not a rule.

In the case no SendDifficulties have been added to the Consensus yet, the spam filter defaults to using a difficulty of 48 "AA" bytes.

They have the following fields:

- nonce: An incrementing number based on the creator used to stop replay attacks.
- difficulty: 384-bit number that should be the difficulty for the Sends' spam filter.

`SendDifficulty` has a message length of 50 bytes; the 2-byte creator's nickname, and the 48-byte difficulty. The signature is produced with a prefix of "\2". That said, `SendDifficulty` is not a standalone message type. This describes how SendDifficulty objects are serialized as part of a `BlockBody` message.

### DataDifficulty

A DataDifficulty is a Merit Holder voting to update the difficulty of the spam filter applied to Datas. The way this difficulty is determined is the exact same as the way the Sends' spam filter difficulty is determined. That said, the difficulty has a lower bound of `000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000`, where any vote for something lower is counted as a vote for this lower bound. Datas with an argon hash below this lower bound are invalid.

In the case no DataDifficulties have been added to the Consensus yet, the spam filter defaults to using a difficulty of 48 "CC" bytes.

They have the following fields:

- nonce: An incrementing number based on the creator used to stop replay attacks.
- difficulty: 384-bit number that should be the difficulty for the Datas' spam filter.

`DataDifficulty` has a message length of 50 bytes; the 2-byte creator's nickname, and the 48-byte difficulty. The signature is produced with a prefix of "\3". That said, `DataDifficulty` is not a standalone message type. This describes how DataDifficulty objects are serialized as part of a `BlockBody` message.

### GasPrice

Unlock Transactions execute MerosScript. Each MerosScript operation has a different amount of "gas" required to be executed. In order to reward Merit Holders for executing MerosScipt, the sender of the Unlock must pay `gasPrice * gas` in Meros.

A GasPrice is a Merit Holder voting to update the gasPrice variable. The way the gasPrice is determined is the exact same as the way the spam filters determine their difficulty except that gas price updates only take effect once archived in a Block.

They have the following fields:

- nonce: An incrementing number based on the creator used to stop replay attacks.
- price: Price in Meri a unit of gas should cost.

`GasPrice` has a message length of 6 bytes; the 2-byte creator's nickname and the 4-byte price (setting a max price of 4.29 Meros per unit of gas). The signature is produced with a prefix of "\4". That said, `GasPrice` is not a standalone message type. This describes how GasPrice objects are serialized as part of a `BlockBody` message.

### MeritRemoval

MeritRemovals aren't created by Merit Holders; they are the sum of two Elements which together define a malicious action. This malicious action is either the verification of competing Transactions or two different Difficulty/Gas Price updates which share the same nonce. Once archived in a Block, Merit Removals remove all Merit from a Merit Holder. Until the Merit Removal is archived, node behavior should not update the amount of 'live' Merit for security reasons. This is further described in the Merit documentation. Merit Holders are ineligible for rewards using removed Merit. Merit Holders may regain Merit, yet if the Block which archives their Merit Removal gives them Merit, it is also removed.

If multiple MeritRemovals are triggered, the first one should have already reverted actions not yet finalized and stripped the Merit Holder of their Merit (according to node behavior). The remaining work becomes achieving consensus on which MeritRemoval is the singular MeritRemoval. This is achieved when the next Block is mined as the next Block's miner decides.

MeritRemovals have the following fields:

- partial:  Whether or not the first Element is already archived on the Blockchain.
- element1: The first Element.
- element2: The second Element.

`MeritRemoval` has a variable message length; the 2-byte creator's nickname, 1-byte of "\1" if partial or "\0" if not, the 1-byte sign prefix for the first Element, the serialized version of the first Element without the creator's nickname, the 1-byte sign prefix for the Element, and the serialized version of the second Element without the creator's nickname. If the sign prefix for an Element is "\1", that means it's a VerificationPacket. The VerificationPacket is serialized including every holder's BLS Public Key, instead of their nickname, without any sorting required. Even though MeritRemovals are not directly signed, they use a prefix of "\5" inside a Block Header's content merkle. That said, `MeritRemoval` is not a standalone message type. This describes how MeritRemoval objects are serialized as part of a `BlockBody` message.

### SignedVerification, SignedSendDifficulty, SignedDataDifficulty, SignedGasPrice, and SignedMeritRemoval

Every "Signed" object is the same as their non-"Signed" counterpart, except they don't rely on a Block's aggregate signature and have the extra field of:

- signature: BLS Signature of the object. In the case of a SignedMeritRemoval, this is the aggregate signature of element1 and element2, unless element1 was already archived on the Blockchain, in which case it's the signature of element2.

Their message lengths are their non-"Signed" message length plus 96 bytes; the 96-byte signature which is appended to the end of the serialized non-"Signed" version.

### Violations in Meros

- Meros doesn't support defaulting.

- Meros doesn't handle `VerificationPacket`.
- Meros doesn't support SendDifficulties or `SignedSendDifficulty`.
- Meros doesn't support DataDifficulties or `SignedDataDifficulty`.
- Meros doesn't support GasPrices or `SignedGasPrice`.

- Meros doesn't support MeritRemovals, despite having the infrastructure.
