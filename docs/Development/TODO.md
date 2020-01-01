# TODO

### Core:

Wallet:

- OpenCAP support.

Database:

- Assign a local nickname to every hash.

Merit:

- Have the Difficulty recalculate every Block based on a window of the previous Blocks/Difficulties, not a period.
- Make RandomX the mining algorithm (node should use the light mode).

Consensus:

- When a packet is archived, recreate the pending packet to include everyone who wasn't included.

- SendDifficulty.
- DataDifficulty.
- GasPrice.

- Same Nonce Merit Removals.
- Verify Competing Merit Removals.

Interfaces:

- Add missing methods detailed under the Eventual docs.
- Correct `personal_getAddress` which is different from its "Eventual" definition.
- Correct `consensus_getSendDifficulty` which is different from its "Eventual" definition.
- Correct `consensus_getDataDifficulty` which is different from its "Eventual" definition.
- Passworded RPC.

- In getBlockTemplate, set the header significance to the minimum significance.

- Meet the following GUI spec: https://docs.google.com/document/d/1-9qz327eQiYijrPTtRhS-D3rGg3F5smw7yRqKOm31xQ/edit

Network:

- Prevent the same client from connecting multiple times.
- Peer finding.
- Node karma.

- Multi-client syncing.
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

Database/Filesystem/DB/Serialize:

- Consensus/SerializeTransactionStatus Test.
- Transactions/SerializeTransaction Test.

Datbase/Filesystem/DB:

- TransactionsDB Tests.
- ConsensusDB Test.
- MeritDB Test.

Database/Consensus:

- Expand the Consensus DB Test to work with more Elements.

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

- Test Mints with multiple outputs.

- Test historical and live threshold calculation.
- Test `TransactionStatus.epoch` is updated as needed.
- Test Meros only verifies Transactions which have a chance.
- Test Transactions with unverified parents aren't verified, yet become verified when their parents are verified.
- Test children Transactions are properly unverified.
- Test that if our Sketcher has a collision, yet the Block's sketch doesn't, Meros still adds the Block.

### Features:

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Use Nim Documentation Comments.
- Meros Whitepaper.
