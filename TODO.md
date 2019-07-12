# TODO

### Core:

Database:

- Assign a local nickname to every key/hash. With nicknames, the first Verification takes up ~52 bytes (hash + nickname), but the next only takes up ~4 (nickname).

Merit:

- Have the Difficulty recalculate every Block based on a window of the previous Blocks/Difficulties, not a period.
- Make RandomX the mining algorithm (node should use the 256 MB mode).

Wallet:

- OpenCAP support.

UI:

- Passworded RPC.
- Usable GUI.

Network:

-
```
proc sync*(
    network: Network,
    consensus: Consensus,
    newBlock: Block
)
```
has several notes in `discard """ """` about syncing transactions which should be resolved.

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

- Prevent the same client from connecting multiple times.
- Peer finding.
- Node karma.

- Multi-client syncing.
- Sync gaps (if we get data after X, but don't have X, sync X; applies to both the Transactions and Consensus DAGs).

### Merit Removals.

Done:
- Object/Lib files.
- Serialize/Parse.
- Check if MeritHolders create conflicting Elements.
- Don't count malicious MeritHolders' verifications.
- Create/broadcast a MeritRemoval for malicious MeritHolders. This MeritRemoval only works where at least one Element's signature is in RAM. If only one signature is in RAM, the other Element must be archived on the current chain.

TODO:
- Check if MeritHolders verify conflicting Transactions.
- Reverse the MeritHolder's pending actions.
- Apply the pending actions if the next Block doesn't contain the MeritRemoval.
- When a Block comes with that MeritRemoval, remove the malicious Merit from the live Merit.
- Save all of this to the database.

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

- Expand the Ed25519 Test.

Datbase/Filesystem/DB/Serialize:

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

UI/RPC:

- UI/RPC/RPC Test.
- UI/RPC/Modules/SystemModule Test.
- UI/RPC/Modules/ConsensusModule Test.
- UI/RPC/Modules/MeritModule Test.
- UI/RPC/Modules/TransactionsModule Test.
- UI/RPC/Modules/PersonalModule Test.
- UI/RPC/Modules/NetworkModule Test.

### Features:

- Add Mints to DBDumpSample.

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

- Have the RPC match the JSON-RPC 2.0 spec.
- `network.rebroadcast(hash or (verifier, nonce))` RPC method.
- Expose more of the Consensus RPC.

- Meet the following GUI spec: https://docs.google.com/document/d/1-9qz327eQiYijrPTtRhS-D3rGg3F5smw7yRqKOm31xQ/edit

### Improvements:

- Swap Chia for Milagro.

- Pass difficulties to the parsing functions to immediately check if work was put into a Block/Transaction (stop DoS attacks).

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Use Nim Documentation Comments.
- Meros Whitepaper.
