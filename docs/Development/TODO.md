# TODO

### Core:

Wallet:

- OpenCAP support.

Database:

- Assign a local nickname to every hash.

Merit:

- Have the Difficulty recalculate every Block based on a window of the previous Blocks/Difficulties, not a period.

Consensus:

- GasPrice.

Interfaces:

- Add missing methods detailed under the Eventual docs.
- Correct `personal_getAddress` which is different from its "Eventual" definition.
- Correct `consensus_getSendDifficulty` which is different from its "Eventual" definition.
- Correct `consensus_getDataDifficulty` which is different from its "Eventual" definition.
- Passworded RPC.

- In getBlockTemplate, set the header significance to the minimum significance.

- Meet the following GUI spec: https://docs.google.com/document/d/1-9qz327eQiYijrPTtRhS-D3rGg3F5smw7yRqKOm31xQ/edit

Network:

- Node karma.

- Sync gaps (if we get data after X, but don't have X, sync X; applies to the Transactions DAG).

- Don't rebroadcast data to who sent it.
- Don't handle Verifications below a Merit threshold.

### Nim Tests:

objects:

- objects/Config Test.

lib:

- Hash/Blake2 Test.
- Hash/Argon Test.

- Expand the Hash/SHA2 Test.
- Expand the Hash/Keccak (384) Test.
- Expand the Hash/SHA3 Test.
- Expand the Hash/RipeMD Test.

- Sketcher Test.
- Logger Test.

Wallet:

- Expand the Ed25519 Test.

Datbase/Filesystem/DB:

- TransactionsDB Tests.
- ConsensusDB Test.
- MeritDB Test.

Database/Merit:

- Expand the Blockchain DB Test to work with Elements.

Database/Consensus/Elements:

- Elements Test.

Network:

- Tests.

### Python Tests

- Add Dead Merit/MeritRemovals to the State Value Test.
- Add same input Claims to the Same Input Test.

- MeritRemoval Tests.
- RPC tests.

- Expand verifyBlockchain to verifyMerit.

- Test historical and live threshold calculation.
- Test `TransactionStatus.epoch` is updated as needed.
- Test Meros only verifies Transactions which have a chance.
- Test Transactions with unverified parents aren't verified, yet become verified when their parents are verified.
- Test children Transactions are properly unverified.
- Test Meros successfully recreates VerificationPackets with the holders not included in the last Block.
- Test that if our Sketcher has a collision, yet the Block's sketch doesn't, Meros still adds the Block.
- Test Blocks with a Difficulty nonce 2 and then Difficulty nonce 1 add correctly.

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Meros Whitepaper.
