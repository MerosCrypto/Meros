# Consensus

"Consensus" is a DAG, similarly structured to the Lattice, containing Verifications, MeritRemovals, Difficulty Updates, and Gas Price sets. The reason it's called Consensus is because even though the Blockchain has the final say, the Blockchain solely distributes Merit (used to weight Consensus) and archives Elements from the Consensus layer,

"Consensus" is made up of MeritHolders (Element array), indexed by BLS Public Keys. Only the key pair behind a MeritHolder can add an Element to it, except in the case of a MeritRemoval. MeritHolders are trusted to only ever have one Element per nonce, unlike Accounts. If a MeritHolder ever has multiple Elements per nonce, they lose all their Merit.

Every Element has the following fields:

- holder: BLS Public Key of the MeritHolder that the Element belongs to.
- nonce: Index of the Element on the MeritHolder. Starts at 0 and increments by 1 for every added Element.

The Element sub-types are as follows:

- Verification
- SendDifficulty
- DataDifficulty
- GasPrice
- MeritRemoval

When a new Element is received via a `SignedVerification`, `SignedSendDifficulty`, `SignedDataDifficulty`, `SignedGasPrice`, or `SignedMeritRemoval` message, it should be added to the holder's MeritHolder, as long as the signature is correct and any other checks imposed by the sub-type pass. Elements don't have hashes, so the signature is produced by signing the serialized version with a prefix. That said, MeritHolders who don't have any Merit can safely have their Elements ignored, as they mean nothing.

The `Verification`, `SendDifficulty`, `DataDifficulty`, `GasPrice`, and `MeritRemoval` messages are only used when syncing, and their signature data is contained in a Block's aggregate signature, as described in the Merit documentation.

### Verification

A Verification is a MeritHolder staking their Merit behind a Entry and approving it. Once a Entry has `LIVE_MERIT / 2 + 601` Merit staked behind it, it is verified. Live Merit is a value described in the Merit documentation. `LIVE_MERIT / 2 + 1` is majority, yet the added 600 covers state changes over the 6 Blocks an Entry can have Verifications added during. A Entry can also be verified through a process known as "defaulting". Once an index is mentioned in a Block, if five more Blocks pass without a transaction becoming verified at that index, the Entry with the most Merit at that index, that is mentioned in a Block, becomes verified.

They have the following fields:

- hash: Hash of the Entry verified.

`Verification` has a message length of 100 bytes; the 48 byte holder, the 4 byte nonce, and the 48 byte hash. The signature is produced with a prefix of "verification".

### SendDifficulty

A SendDifficulty is a MeritHolder voting to update the difficulty of the spam filter applied to Sends. Every MeritHolder gets one vote per 10,000 Merit. Every MeritHolder can specify a singular difficulty which all their votes goes towards. The difficulty that is the median of all votes is chosen.

The 10,000 Merit limit creates a maximum of 525 votes. The multiple votes per MeritHolder means MeritHolders with more Merit get more power. The median means that if the difficulty is 10, and a MeritHolder wants it to be 9, they can't game the system by voting for 8.

When the difficulty is lowered, there's a chance Entries based off the new difficulty may be rejected by nodes still using the old difficulty. When the difficulty is raised, there's a chance Entries based off the old difficulty may still be accepted by nodes still using the old difficulty. The first just adds a delay to the system, and adding a Block will catch all the nodes up. The second risks rewinding Entries. Therefore, if an Entry doesn't beat the spam filter, but does still get the needed Verifications to become verified, it's still valid.

In the case no SendDifficulties have been added to the Consensus yet, the spam filter defaults to using a difficulty of 48 "AA" bytes.

They have the following fields:

- difficulty: 384-bit number that should be the difficulty for the Sends' spam filter.

`SendDifficulty` has a message length of 100 bytes; the 48 byte holder, the 4 byte nonce, and the 48 byte difficulty. The signature is produced with a prefix of "sendDifficulty".

### DataDifficulty

A DataDifficulty is a MeritHolder voting to update the difficulty of the spam filter applied to Datas. The way this difficulty is determined is the exact same as the way the Sends' spam filter difficulty is determined.

In the case no DataDifficulties have been added to the Consensus yet, the spam filter defaults to using a difficulty of 48 "CC" bytes.

They have the following fields:

- difficulty: 384-bit number that should be the difficulty for the Datas' spam filter.

`DataDifficulty` has a message length of 100 bytes; the 48 byte holder, the 4 byte nonce, and the 48 byte difficulty. The signature is produced with a prefix of "dataDifficulty".

### GasPrice

Unlock Entries execute MerosScript. Each MerosScript operation has a different amount of "gas" required to be executed. In order to reward MeritHolders for executing MerosScipt, the sender of the Unlock must pay `gasPrice * gas` in Meros.

A GasPrice is a MeritHolder voting to update the gasPrice variable. The way the gasPrice is determined is the exact same as the way the spam filters determine their difficulty.

They have the following fields:

- price: Price in Meri an unit of gas should cost.

`GasPrice` has a message length of 56 bytes; the 48 byte holder, the 4 byte nonce, and the 4 byte price (setting a max price of 4.29 Meros per unit of gas). The signature is produced with a prefix of "gasPrice".

### MeritRemoval

MeritRemovals aren't created on their own. When a MeritHolder creates two Elements with the same nonce, or two Verifications at different nonces which verify competing Entries, nodes add a MeritRemoval to the MeritHolder. This MeritRemoval is added right after the archived Elements. All unarchived Elements have their actions reversed, and can be safely pruned once the MeritRemoval is included in a Block.

The creation of a MeritRemoval causes the MeritHolder's Merit to exit the system, so their Merit no longer affects the amount of live Merit in the system. This is further described in the Merit documentation.

If a MeritRemoval is triggered at multiple nonces, or with more than two Elements, the first one will have already reverted unarchived actions and strip the MeritHolder of their Merit. The question becomes solely what Elements to name as the MeritRemoval's cause. This is at the next Block's miner's discretion, and whatever Elements they pick becomes the cause for the entire network.

MeritRemovals have the following fields:

- Element1: The first Element.
- Element2: The second Element.

`MeritRemoval` isn't needed per se. Instead, nodes could just broadcast both causes. The unified message ensures nodes get both causes and trigger a MeritRemoval on their end. It has a variable message length; the 48 byte holder, the 4 byte nonce, the 1 byte message header for the first Element, the serialized version of the first Element without the holder, the 1 byte message header for the Element, and the serialized version of the second Element without the holder.

### SignedVerification, SignedSendDifficulty, SignedDataDifficulty, SignedGasPrice, SignedMeritRemoval

Every "Signed" object is the same as their non-"Signed" counterpart, except they don't rely on a Block's aggregate signature and have the extra field of:

- signature: BLS Signature of the object. In the case of a SignedMeritRemoval, this is the aggregate signature of Element1 and Element2.

Their message lengths are their non-"Signed" message length plus 96 bytes; the 96 byte signature which is appended to the end of the serialized non-"Signed" version.

### Violations in Meros

- Meros doesn't support defaulting.
- Meros doesn't support `SignedSendDifficulty` or `SendDifficulty`.
- Meros doesn't support `SignedDataDifficulty` or `DataDifficulty`.
- Meros doesn't support `SignedGasPrice` or `GasPrice`.
- Meros doesn't support `SignedMeritRemoval` or `MeritRemoval`.