# TODO

### Core:
Wallet:
- Mnemonic file to convert a Mnemonic to seed, and vice versa.
- HDWallet type which meets the specs defined in https://cardanolaunch.com/assets/Ed25519_BIP.pdf and creates Wallets.
- OpenCAP support.

Database:
- If we actually create three separate database, instead of using `verifications_`, `merit_`, and `lattice_`, we'd save space on disk and likely have better performance.
- If we don't commit after every edit, but instead after a new Block, we create a more-fault tolerant DB that will likely also handle becoming threaded better.
- Assign a local nickname to every hash. The first vote takes up ~52 bytes (hash + nickname), but the next only takes up ~4 (nickname).

Consensus:
- Load unarchived Elements from the DB.

Merit:
- Chain reorgs.
- Make RandomX the mining algorithm (node should use the 256 MB mode).
- Don't just hash the block header; include random sampling to force miners to run full nodes.
- Improve the Difficulty algorithm.

Lattice:
- Cache the UXTO set.

Network:
- Don't rebroadcast data that we're syncing.

- Prevent the same client from connecting multiple times.
- Peer finding.
- Node karma.

- Multi-client syncing.
- Sync gaps (if we get data with nonce 2 but we only have 0, sync 1 and 2; applies to both the Lattice and Consensus DAGs).

### Tests:
Cleanup Tests (as in, they need to be cleaned (especially LatticeTest)).

objects:
- objects/Config Test.

lib:
- lib/Hash/Argon Test.
- lib/Hash/Blake2 Test.
- lib/Hash/SHA2 (384) Test.
- lib/Hash/Keccak (384) Test.
- lib/Hash/SHA3 (384) Test.
- lib/Hash/HashCommon Tests.
- lib/Logger Test.

Wallet:
- Wallet/Ed25519 Test.
- Wallet/MinerWallet Test.
- Wallet/Wallet Test.

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
- Network/Serialize/Lattice/ParseEntry Test.

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

- Explain `Lock`s/`Unlock`s.

- Define what happens when a Verifier confirms X + 1, but not X, when X has yet to be mentioned in a Block.
- Define what happens when a Verifier confirms a Receive who's Send doesn't become confirmed.

- Define the Difficulty algorithm.
- Define the Merkle tree construction for miners (in Merit)/MeritHolders (in Consensus).
- Explain Dead Merit.
- Explain Checkpoints.
- Explain Rewards (including how cutoff rewards are carried over).
- Talk about chain reorgs.

- Meros Whitepaper.
