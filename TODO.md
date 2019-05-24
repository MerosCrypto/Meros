# TODO

### Core:
Wallet:

- Mnemonic file to convert a Mnemonic to seed, and vice versa.
- HDWallet type which meets the specs defined in https://cardanolaunch.com/assets/Ed25519_BIP.pdf and creates Wallets.
- OpenCAP support.

Database:

- Abstract the Database. Caching should still be handled by the Lattice/Consensus/Merit, but Database should have its own Serialize folder and supply `save(entry: Entry)` and so on.
- If we actually create three separate database, instead of using `consensus`, `merit_`, and `lattice_`, we'd save space on disk and likely have better performance.
- If we don't commit after every edit, but instead after a new Block, we create a more-fault tolerant DB that will likely also handle becoming threaded better.
- Assign a local nickname to every hash. The first vote takes up ~52 bytes (hash + nickname), but the next only takes up ~4 (nickname).

Merit:

- Have the Difficulty recalculate every Block based on a window of the previous Blocks/Difficulties, not a period.
- Make RandomX the mining algorithm (node should use the 256 MB mode).
- Don't just hash the block header; include random sampling to force miners to run full nodes.

Lattice:

- The claimable table is currently no better than a seq. Either use it with the benefits of a Table and turn it into a seq.
- Cache the UXTO set.

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
- Sync gaps (if we get data with nonce 2 but we only have 0, sync 1 and 2; applies to both the Lattice and Consensus DAGs).

### Tests:
Cleanup:

- Database/Consensus Cleanup.
- Database/Merit Cleanup.

objects:

- objects/Config Test.

lib:

- lib/Hash/Argon Test.
- lib/Hash/Blake2 Test.
- lib/Hash/SHA2 (384) Test.
- lib/Hash/Keccak (384) Test.
- lib/Hash/SHA3 (384) Test.
- lib/Hash/HashCommon Test.
- Fuzzy lib/Util Test.
- lib/Logger Test.

Wallet:

- Wallet/Ed25519 Test.

Database/Consensus:

- Database/Consensus/Verifier Test.
- Database/Consensus/Verification Test.

Database/Merit:

- Database/Merit/BlockHeader Test.
- Database/Merit/Block Test.
- Database/Merit/Difficulty Test.
- Database/Merit/Merit Test.
- Add DB writeups, like the one in the ConsensusTest, to BlockchainTest, StateTest, and EpochsTest.

Database/Lattice:

- Database/Lattice/Entry Test.
- Database/Lattice/Mint Test.
- Database/Lattice/Claim Test.
- Database/Lattice/Send Test.
- Database/Lattice/Receive Test.
- Database/Lattice/Data Test.
- Database/Lattice/Account Test.
- Add competing Entries to the Lattice's DB Test.

Network:

- Tests.

Network/Serialize/Lattice:

- Network/Serialize/Lattice/SerializeEntry Test.

UI/RPC:

- UI/RPC/RPC Test.
- UI/RPC/Modules/SystemModule Test.
- UI/RPC/Modules/ConsensusModule Test.
- UI/RPC/Modules/MeritModule Test.
- UI/RPC/Modules/LatticeModule Test.
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

- Loading screen.
- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:

- Swap Chia for Herumi.

- Cache the Lattice's UXTO set.
- Pass difficulties to the parsing functions to immediately check if work was put into a Block/Entry (stop DoS attacks).

- Remove holders who lost all their Merit from `merit_holders`.

### Documentation:

- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Use Nim Documentation Comments.
- Meros Whitepaper.
