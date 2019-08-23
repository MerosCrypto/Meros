# TODO

### Core:

Wallet:

- OpenCAP support.

Database:

- Assign a local nickname to every key/hash. With nicknames, the first Verification takes up ~52 bytes (hash + nickname), but the next only takes up ~4 (nickname).

Merit:

- Have the Difficulty recalculate every Block based on a window of the previous Blocks/Difficulties, not a period.
- Make RandomX the mining algorithm (node should use the light mode).
- Decide if Block aggregate should be aggregate(MeritHolderAggregates) or aggregate(signatures).

Consensus:

- Check if MeritHolders verify conflicting Transactions.
- SendDifficulty.
- DataDifficulty.

Transactions:

- Resolve https://github.com/MerosCrypto/Meros/issues/84.
- Correctly "unverify" Transactions. We do not mark Transactions as no longer eligible for defaulting (if that's the case), re-enable spent UTXOs, or unverify child Transactions.
- Raise the Verification threshold.
- Reload Verifications with their MeritHolder's current Merit. The only reason we don't do this now is our low threshold/it breaks consistency on reload.

UI:

- Add missing methods detailed under the Eventual docs.
- Correct `personal_getAddress` which is different from its "Eventual" definition.
- Correct `transactions_getMerit` which is different from its "Eventual" definition.
- Passworded RPC.

- Meet the following GUI spec: https://docs.google.com/document/d/1-9qz327eQiYijrPTtRhS-D3rGg3F5smw7yRqKOm31xQ/edit

Network:

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

- Element Test.
- Verification Test.
- SendDifficulty Test.
- DataDifficulty Test.
- GasPrice Test.
- MeritRemoval Test.
- MeritHolder Test.
- Expand the Consensus DB Test to work with other Elements.

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

### Features:

- Add Mints to DBDumpSample.

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

### Improvements:

- Remove EdPublicKeyError.

- Swap Chia for Milagro.

- Pass difficulties to the parsing functions to immediately check if work was put into a Block/Transaction (stop DoS attacks).

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Use Nim Documentation Comments.
- Meros Whitepaper.
