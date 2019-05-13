# Consensus

"Consensus" is a DAG, similarly structured to the Lattice, containing Verifications, MeritRemovals, Difficulty Updates, and Gas Price sets. The reason it's called Consensus is because even though the Blockchain has the final say, the Blockchain solely distributes Merit (used to weight Consensus) and archives Elements from the Consensus layer,

"Consensus" is made up of MeritHolders (Element array), indexed by BLS Public Keys. Only the key pair behind a MeritHolder can add an Element to it. MeritHolders are trusted to only ever have one Element per nonce, unlike Accounts. If a MeritHolder ever has multiple Elements per nonce, they lose all their Merit.

Every Element has the following fields:

- sender: BLS Public Key of the MeritHolder that the Element belongs to.
- nonce: Index of the Element on the MeritHolder. Starts at 0 and increments by 1 for every added Element.

The Element sub-types are as follows:

- Verification
- SendDifficulty
- DataDifficulty
- GasPrice
- MeritRemoval

When a new Element is received via a `SignedVerification`, `SignedSendDifficulty`, `SignedDataDifficulty`, `SignedGasPrice`, or `SignedMeritRemoval` message, it should be added to the sender's MeritHolder, as long as the signature is correct and any other checks imposed by the sub-type pass. Elements don't have hashes, so the signature is produced by signing the serialized version with a prefix. That said, MeritHolders who don't have any Merit can safely have their Elements ignored, as they mean nothing.

The `Verification`, `SendDifficulty`, `DataDifficulty`, `GasPrice`, and `MeritRemoval` messages are only used when syncing, and their signature data is contained in a Block's aggregate signature, as described in the Merit documentation.

### Verification

A Verification is a MeritHolder staking their Merit behind a transaction and approving it. Once a transaction has `LIVE_MERIT / 2 + 601` Merit staked behind it, it is confirmed. Live Merit is a value described in the Merit documentation. `LIVE_MERIT / 2 + 1` is majority, yet the added 600 covers state changes over the 6 Blocks an Entry can have Verifications added during.

They have the following fields:

- hash: Hash of the Entry verified.

`Verification` has a message length of 100 bytes; the 48 byte sender, the 4 byte nonce, and the 48 byte hash. The signature is produced with a prefix of "verification".

### SendDifficulty

### DataDifficulty

### GasPrice

### MeritRemoval

### SignedVerification

SgnedVerifications are the same as Verifications, yet they contain their BLS Signature, instead of relying on a Block's aggregate signature. They have the extra field of:

- signature: BLS Signature of the Verification.

`SignedVerification` has a message length of 196 bytes; the `Verification` message with the 86 byte signature appended.

### SignedSendDifficulty

### SignedDataDifficulty

### SignedGasPrice

### SignedMeritRemoval

### Violations in Meros

- Meros doesn't support `SignedSendDifficulty` or `SendDifficulty`.
- Meros doesn't support `SignedDataDifficulty` or `DataDifficulty`.
- Meros doesn't support `SignedGasPrice` or `GasPrice`.
- Meros doesn't support `SignedMeritRemoval` or `MeritRemoval`.
