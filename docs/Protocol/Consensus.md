# Consensus

"Consensus" is a DAG, similarly structured to the Lattice, containing Verifications, MeritRemovals, Difficulty Updates, and Gas Price sets. The reason it's called Consensus is because even though the Blockchain has the final say, the Blockchain solely distributes Merit (used to weight Consensus) and archives elements from the Consensus layer,

"Consensus" is made up of Verifiers (Element array), indexed by BLS Public Keys. Only the key pair behind a Verifier can add an Element to it. Verifiers are trusted to only ever have one Element per nonce, unlike Accounts. If a Verifier ever has multiple Elements per nonce, they lose all their Merit.

Every Element has the following fields:
- sender: BLS Public Key of the Verifier that the Element belongs to.
- nonce: Index of the Element on the Verifier. Starts at 0 and increments by 1 for every added Element.

The Element sub-types are as follows:
- Verification
- SendDifficulty
- DataDifficulty
- GasPrice
- MeritRemoval

When a new Element is received via a `SignedVerification`, `SignedSendDifficulty`, `SignedDataDifficulty`, `SignedGasPrice`, or `SignedMeritRemoval` message, it should be added to the sender's Verifier, as long as the signature is correct and any other checks imposed by the sub-type pass.

### SignedVerification

### SignedSendDifficulty

### SignedDataDifficulty

### SignedGasPrice

### SignedMeritRemoval

### Verification

### SendDifficulty

### DataDifficulty

### GasPrice

### MeritRemoval

### Violations in Meros

- Meros doesn't support SignedSendDifficulty or SendDifficulty.
- Meros doesn't support SignedDataDifficulty or DataDifficulty.
- Meros doesn't support SignedGasPrice or GasPrice.
- Meros doesn't support SignedMeritRemoval or MeritRemoval.
