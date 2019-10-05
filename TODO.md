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

- Sync missing Blocks when we receive a `Block` with a nonce higher than our block height.
- Sync missing Blocks when we receive a `BlockHeight` with a higher block height than our own.

- Syncing currently works by:
    - Get the hash of the next Block.
    - Get the BlockHeader.
    - Get the BlockBody.
    - Sync all the Elements from the Block.
    - Sync all the Entries from the Elements.
    - Add the Block.

	Switching this to:

    - Get the hash of the next Block who's nonce modulus 5 == 0.
    - Get the Checkpoint.
    - Sync every BlockHeader in the checkpoint, in reverse order.
    - For each BlockHeader, in order:
        - Test the BlockHeader.
        - Sync the BlockBody.
        - Sync all the Elements from the Block.
        - Sync all the Entries from the Elements.
        - Add the Block.
    - When there are no more Checkpoints, get the hash of each individual Block...

	Will reduce network traffic and increase security.

- Check requested data is requested data. We don't do this for Block Bodies, and perform a very weak check for Elements (supplement with a signature/record merkle check).
- Prevent the same client from connecting multiple times.
- Peer finding.
- Node karma.

- Multi-client syncing.
- Sync gaps (if we get data after X, but don't have X, sync X; applies to both the Transactions and Consensus DAGs).

- Handle ValidityConcerns.
- Don't rebroadcast data to who sent it.
- Don't rebroadcast Elements below a Merit threshold.

### No Consensus DAG:

- Verify the `contents` merkle when syncing the Block Body (currently done in Blockchain.processBlock).
- Verify the `verifiers` merkle when we verify the Block's aggregate signature.
- Verify Elements don't cause a MeritRemoval in MainMerit (as well as the fact they have yet to be archived).

- Epochs's getPackets.
- Load statuses still in Epochs.
- Load close Transactions.
- Functioning checkMalicious.

- Functioning getBlockTemplate. The existing one meets the RPC spec but includes no TXs or Elements.
- Correct `personal_getAddress` which is different from its "Eventual" definition.

- Epochs Tests.
- Add Elements to BDBTest.
- Re-enable StateTests/ValueTest.

- Test successful recreation of VerificationPackets which include Merit Holders which weren't included in the archived packet.
- Test the full nickname space is usable both internally and in parsing/serializations.

- Remove no longer needed Exception checks.

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

- Consensus/DBSerializeElement Test.
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

- Pass the Blockchain Difficulty to the Block parser to immediately check if work was put into it.

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Use Nim Documentation Comments.
- Meros Whitepaper.
