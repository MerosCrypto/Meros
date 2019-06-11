# TODO

### Transactions and DB Redo

- Data Transactions.
- Reload Transactions from the DB.
- MainTransactions.
- New Transactions RPC.
- Rebuild the Personal RPC.

### Core:

Config:

- Enable testnet connectivity via the config.

Database:

- If we don't commit after every edit, but instead after a new Block, we create a more-fault tolerant DB that will likely also handle becoming threaded better.
- Assign a local nickname to every hash. The first vote takes up ~52 bytes (hash + nickname), but the next only takes up ~4 (nickname).

Merit:

- Have the Difficulty recalculate every Block based on a window of the previous Blocks/Difficulties, not a period.
- Make RandomX the mining algorithm (node should use the 256 MB mode).
- Don't just hash the block header; include random sampling to force miners to run full nodes.

Wallet:

- Mnemonic file to convert a Mnemonic to seed, and vice versa.
- OpenCAP support.

UI:

- Passworded RPC.

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

- Don't rebroadcast data that we're syncing.

- Prevent the same client from connecting multiple times.
- Peer finding.
- Node karma.

- Multi-client syncing.
- Sync gaps (if we get data with nonce 2 but we only have 0, sync 1 and 2; applies to both the Transactions and Consensus DAGs).

### Tests:

objects:

- objects/Config Test.

lib:

- Hash/Blake2 Test.
- Hash/Argon Test.
- Hash/RandomX Test.

- Hash/SHA2 (384) Test.
- Hash/Keccak (384) Test.
- Hash/SHA3 (384) Test.

- Hash/HashCommon Test.

- Logger Test.

Wallet:

- Ed25519 Test.


Datbase/Filesystem/DB/Serialize:

- Transactions/SerializeTransaction Test.

Datbase/Filesystem/DB:

- TransactionsDB Test.
- ConsensusDB Test.
- MeritDB Test.

Database/Consensus:

- MeritHolder Test.
- Verification Test.

Database/Merit:

- BlockHeader Test.
- Block Test.
- Difficulty Test.
- Merit Test.
- Add DB writeups, like the one in the ConsensusTest, to BlockchainTest, StateTest, and EpochsTest.

Database/Transactions:

- Transaction Test.
- Mint Test.
- Claim Test.
- Send Test.

Network:

- Tests.

UI/RPC:

- UI/RPC/RPC Test.
- UI/RPC/Modules/SystemModule Test.
- UI/RPC/Modules/ConsensusModule Test.
- UI/RPC/Modules/MeritModule Test.
- UI/RPC/Modules/TransactionsModule Test.
- UI/RPC/Modules/PersonalModule Test.
- UI/RPC/Modules/NetworkModule Test.

### Features:

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

- Have the RPC match the JSON-RPC 2.0 spec.
- Have the RPC dynamically get the nonce (it's currently an argument).
- `network.rebroadcast(address | verifier, nonce)` RPC method.
- Expose more of the Consensus RPC.

- Meet the following GUI spec: https://docs.google.com/document/d/1-9qz327eQiYijrPTtRhS-D3rGg3F5smw7yRqKOm31xQ/edit

### Improvements:

- Swap Chia for Milagro.

- Pass difficulties to the parsing functions to immediately check if work was put into a Block/Transaction (stop DoS attacks).

- Remove holders who lost all their Merit from `merit_holders`.

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Use Nim Documentation Comments.
- Meros Whitepaper.
