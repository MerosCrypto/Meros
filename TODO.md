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

- Save/reload unarchived MeritRemovals.
- Check if Merit Holders verify conflicting Transactions.
- SendDifficulty.
- DataDifficulty.
- GasPrice.

UI:

- Add missing methods detailed under the Eventual docs.
- Correct `personal_getAddress` which is different from its "Eventual" definition.
- Correct `transactions_getMerit` which is different from its "Eventual" definition.
- Passworded RPC.

- Meet the following GUI spec: https://docs.google.com/document/d/1-9qz327eQiYijrPTtRhS-D3rGg3F5smw7yRqKOm31xQ/edit

Network:

- Check requested data is requested data.
- Prevent the same client from connecting multiple times.
- Peer finding.
- Node karma.

- Multi-client syncing.
- Sync gaps (if we get data after X, but don't have X, sync X; applies to the Transactions DAG).

- Don't rebroadcast data to who sent it.
- Don't handle Verifications below a Merit threshold.

### No Consensus DAG:

Wallet:

- Load the nickname/automatically set the nickname for the miner wallet.

Merit:

- If our sketch has a collision, check if the Block doesn't (as that would mean it's valid).
- If we sync a Block with a working sketch yet invalid merkle, check if there was a collision between one of our elements and one we didn't have which was included in the sketch.

Consensus:

- Load statuses still in Epochs.
- Load close Transactions.
- Functioning checkMalicious.

RPC:

- Functioning getBlockTemplate/publishBlock. These were disabled when we added sketches.

Network:

- Message receiving uses a last positive to support X, -Y, -Z where Y and Z are both multiples of X. This was added to support having two sketches in a row which share a capacity. This functionality is no longer needed and should likely be removed.

- Check if sketches should be saved to the Database to save speed when BlockBodyRequests are sent (question raised by https://github.com/MerosCrypto/Meros/issues/97).

- Move the sketchCheck check into requestVerificationPackets.

Tests:

- Add Elements to BDBTest.
- Add Dead Merit/MeritRemovals to the State Value Test.
- Add MeritRemovals to EDBTest.

- Sketcher Test.

- Test successful recreation of VerificationPackets which include Merit Holders which weren't included in the archived packet.
- Test the full nickname space is usable both internally and in parsing/serializations.

Cleanup:

- Remove no longer needed Exception checks.
- Remove latent """ marks.

### Nim Tests:

objects:

- objects/Config Test.

lib:

- Hash/Blake2 Test.
- Hash/Argon Test.

- Hash/SHA2 (384) Test.
- Hash/Keccak (384) Test.
- Hash/SHA3 (384) Test.

- Hash/HashCommon Test.

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

Database/Transactions:

- Mint Test.
- Claim Test.
- Send Test.
- Data Test.

Database/Consensus:

- TransactionStatus Test.
- Expand the Consensus DB Test to work with more Elements.

Database/Consensus/Elements:

- Element Test.
- Verification Test.
- VerificationPacket Test.
- SendDifficulty Test.
- DataDifficulty Test.
- GasPrice Test.
- MeritRemoval Test.

Database/Merit:

- BlockHeader Test.
- Block Test.
- Difficulty Test.
- Merit Test.

Network:

- Tests.

### Python Tests

- RPC tests.

- VerifyCompeting Sync test.
- VerifyCompeting Live test.
- VerifyCompeting Cause test.

- PendingActionsTest should not have all reverted actions reapplied.

- Test historical and live threshold calculation.
- Test `TransactionStatus.epoch` is updated as needed.
- Test Meros only verifies Transactions which have a chance.
- Test Transactions with unverified parents aren't verified, yet become verified when their parents are verified.
- Test children Transactions are properly unverified.

### Features:

- Add Mints to DBDumpSample.

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

### Improvements:

- Remove EdPublicKeyError.

- Swap Chia for Milagro.

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Use Nim Documentation Comments.
- Meros Whitepaper.
