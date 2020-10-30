# Consensus

This document defines and describes Consensus Elements, which come in the forms of Verifications, Difficulty Updates, and Merit Removals. Every Element has a holder, which is the 2-byte nickname of the Merit Holder who created it. When a new Element is received via a `SignedVerification`, `SignedSendDifficulty`, `SignedDataDifficulty`, or `SignedMeritRemoval` message, node behavior should be to immediately perform the protocol dictated action, as long as the Element is valid.

Elements do not have hashes, so their signatures are produced by signing their serialization, without the holder, and with a prefix unique to each type of Element.

It should be noted `Verification`, `VerificationPacket`, `SendDifficulty`, `DataDifficulty`, and `MeritRemoval` aren't actual message types. `Verification` only exists to define the `SignedVerification` message type. The rest only exist to define their signed variants, as well define how they're included as part of a `BlockBody` message.

### Verification

A Verification is a Merit Holder staking their Merit behind a Transaction and approving it. If a Transaction has `LIVE_MERIT / 2 + 1` Merit staked behind it at the end of its Epoch, it is verified. Live Merit is described in the Merit documentation, and the Live Merit value used is what it will be at the end of the Transaction's Epoch. It should be noted Meros considers a Transaction verified as soon as it crosses its threshold, which uses a different formula than the protocol. If a Verification isn't archived by the end of these 6 Blocks, it should not be counted towards the Transaction's final Merit. Transactions can also be verified through a process known as "defaulting". Once a Epoch finalizes, if it contains a Transaction spending an input who doesn't have a spender with the needed Merit to become verified, the on-chain spending Transaction with the most Merit becomes verified at the Checkpoint after the next Checkpoint. In the case of a tie, the tied Transaction with the lower hash becomes verified.

It is possible for a Merit Holder who votes on competing Transactions using the same input to cause both to become verified. This is eventually resolved, as described below in the `MeritRemoval` section, yet raises the risk of reverting a Transaction's verification. There are multiple ways to prevent this and handle it in the moment, yet the Meros protocol is indifferent, as long as all nodes resolve it and maintain consensus. If Meros detects multiple Transactions sharing an input, it will wait for a Transaction to default, not allowing for verification via Verifications alone. Meros also requires an 80% threshold to be crossed before marking a Transaction as verified, not a 50.1% threshold.

They have the following fields:

- hash: Hash of the Transaction verified.

Verifications, except when present in a MeritRemoval, can only be of valid Transactions, meaning Transactions which have been mentioned on the chain or still can be mentioned in a future Block. The Transaction does NOT have to beat any spam filter. When present in a MeritRemoval, Verifications can be of any parsable Transaction. This is in case a MeritRemoval is delayed to the point a Transaction can no longer be included on the chain. Parsable is defined as being a valid network message whose BLS Public Keys/Signatures represent on-curve points.

`Verification` has a message length of 34 bytes; the 2-byte holder and the 32-byte hash. The signature is produced with a prefix of "\0".

### VerificationPacket

A Verification packet is a group of Verifications belonging to a single Transaction. They use less bandwidth than individual Verifications and are faster to handle in the moment as their signed version uses a single signature for every message.

`VerificationPacket` has a variable message length; the 2-byte amount of Verifications, the verifiers (each represented by their 2-byte nickname, in ascending order), and the 32-byte hash. Even though VerificationPackets are not directly signed, they use a prefix of "\1" inside a Block Header's content Merkle.

### SendDifficulty

A SendDifficulty is a Merit Holder voting to update the difficulty of the spam filter applied to Sends. Every Merit Holder gets one vote per 50 Merit. Every Merit Holder can specify a singular difficulty which is voted on by all their votes. The difficulty that is the median of all votes is chosen (where if two medians are presented, the higher one is chosen). The 50 Merit per vote creates a maximum of 1051 votes. The multiple votes per Merit Holder stops sybil attacks, correctly weighing against the Merit Holder's power. The choice of median over mean stops Merit Holders from being incentivized to vote far from their target in order to have more power.

When the difficulty is lowered, there's a chance Transactions based on the new difficulty may be rejected by nodes still using the old difficulty. When the difficulty is raised, there's a chance Transactions based on the old difficulty may still be accepted by nodes who have yet to update. The first scenario adds a delay to the system, and adding a Block will catch all the nodes up. The second scenario risks rewinding Transactions. Therefore, if a Transaction doesn't beat the spam filter, but does still get the needed Verifications to become verified, it's still valid. This makes the difficulty a coordinated guideline, not a rule.

In the case no SendDifficulties have been added to the spam filter yet, the spam filter defaults to using the initial difficulty, as described in the Difficulty documentation.

They have the following fields:

- nonce: An incrementing number based on the Merit Holder used to stop replay attacks.
- difficulty: An unsigned 64-bit number representing the difficulty for the Send Transactions' spam filter.

`SendDifficulty` has a message length of 10 bytes; the 2-byte holder, 4-byte nonce, and the 4-byte difficulty. The signature is produced with a prefix of "\2". That said, `SendDifficulty` is not a standalone message type.

### DataDifficulty

A DataDifficulty is a Merit Holder voting to update the difficulty of the spam filter applied to Data Transactions. The way this difficulty is determined is the exact same as the way the Sends' spam filter difficulty is determined.

In the case no DataDifficulties have been added to the spam filter yet, the spam filter defaults to using the initial difficulty, as described in the Difficulty documentation.

They have the following fields:

- nonce: An incrementing number based on the Merit Holder used to stop replay attacks.
- difficulty: An unsigned 64-bit number representing the difficulty for the Data Transactions' spam filter.

`DataDifficulty` has a message length of 10 bytes; the 2-byte holder, 4-byte nonce, and the 4-byte difficulty. The signature is produced with a prefix of "\3". That said, `DataDifficulty` is not a standalone message type.

### MeritRemoval

MeritRemovals aren't created by Merit Holders; they are the sum of two Elements which together define a malicious action. This malicious action is either the verification of competing Transactions or two different Difficulty updates which share the same nonce. Once archived in a Block, Merit Removals remove all Merit from a Merit Holder. Until the Merit Removal is archived, node behavior should not update the amount of 'live' Merit for security reasons. This is further described in the Merit documentation. Merit Holders are ineligible for rewards using removed Merit. Merit Holders may regain Merit, yet if the Block which archives their Merit Removal gives them Merit, it is also removed.

If multiple MeritRemovals are triggered, the first one should have already reverted actions not yet finalized and stripped the Merit Holder of their Merit (according to node behavior). The remaining work becomes achieving consensus on which MeritRemoval is the singular MeritRemoval. This is achieved when the next Block is mined as the next Block's miner decides.

MeritRemovals have the following fields:

- partial:  Whether or not the first Element is already archived on the Blockchain.
- element1: The first Element.
- element2: The second Element.

`MeritRemoval` has a variable message length; the 2-byte holder, 1-byte of "\1" if partial or "\0" if not, the 1-byte sign prefix for the first Element, the serialized version of the first Element without the holder, the 1-byte sign prefix for the Element, and the serialized version of the second Element without the holder. If the sign prefix for an Element is "\1", that means it's a VerificationPacket. The VerificationPacket is serialized including every Merit Holder's BLS Public Key, instead of their nickname, without any sorting required. This is to enable MeritRemovals involving holders whose nicknames were lost due to a chain reorganization. None of the included keys may be infinite. Even though MeritRemovals are not directly signed, they use a prefix of "\5" inside a Block Header's content Merkle. That said, `MeritRemoval` is not a standalone message type.

If a same-nonce MeritRemoval occurs, and the Merit Holder regains enough Merit to vote on Send/Data Difficulties, the regained vote must not use a nonce which has an archived MeritRemoval.

### SignedVerification, SignedSendDifficulty, SignedDataDifficulty, and SignedMeritRemoval

Every "Signed" object is the same as their non-"Signed" counterpart, except they don't rely on a Block's aggregate signature and have the extra field of:

- signature: BLS Signature of the object. In the case of a SignedMeritRemoval, this is the aggregate signature of element1 and element2, unless element1 was already archived on the Blockchain, in which case it's the signature of element2.

Their message lengths are their non-"Signed" message length plus 48 bytes; the 48-byte signature which is appended to the end of the serialized non-"Signed" version.
