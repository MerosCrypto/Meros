# TODO

### Cleanup:
General Cleanup:
- Decide a definitive import ordering and make sure it's used throughout the codebase.

- Use `let` where appropriate.
- Remove `ref` from objects that shouldn't be `ref`.
- Remove `of RootObj` from objects that aren't inherited from.

- Make more `proc`s `func`.

Specific Tasks:
- Add `DataExists` for when data has already been added.

- Correct the `toTrim` variable calculation Verifier.nim (requires MainMerit).
- `verifications.getPendingAggregate` has a very specific use case and it should be merged with `verifications.getUnarchivedIndexes`.

- Clean NetworkSync.
- Make sure raises changes for the following are propogated appropriately:
    - Network.connect (ClientError)
    - Network.requestBlock (?)
- Move broadcast for Entries from the Network/RPC to Main, to match Blocks and also be able to remove the 100ms verify delay.
- Move broadcast for Verifications from the Network/RPC to Main, to match Blocks and Entries.

- Clean tests.

- Update some `raise`s in the PersonalModule to `doAssert(false)`.

- Don't rebroadcast data that we're syncing.
- Remove the code from MainMerit that verifies we have everything mentioned in a Block and the block's aggregate. NetworkSync should raise an error if it fails to sync something, and we verify the signature in NetworkSync in order to verify we're not adding forged Verifications.
- Pass difficulties to the parsing functions to immediately check if work was put into a Block/Entry (stop DoS attacks).

Tests:
- lib/Raw Test.
- lib/Hash/Argon Test.
- lib/Hash/Blake2 Test.
- lib/Hash/SHA2 (384) Test.
- lib/Hash/Keccak (384) Test.
- lib/Hash/SHA3 (384) Test.

- Network/Serialize/Lattice/SerializeEntry Test.
- Network/Serialize/Lattice/ParseEntry Test.

### Core:
Wallet:
- Mnemonic file to convert a Mnemonic to seed, and vice versa.
- HDWallet type which meets the specs defined in https://cardanolaunch.com/assets/Ed25519_BIP.pdf and creates Wallets.

Database:
- If we actually create three separate database, instead of using `verifications_`, `merit_`, and `lattice_`, we'd save space on disk and likely have better performance.
- If we don't commit after every edit, but instead after a new Block, we create a more-fault tolerant DB that will likely also handle becoming threaded better.
- Assign a local nickname to every hash. The first vote takes up ~52 bytes (hash + nickname), but the next only takes up ~4 (nickname).

Verifications:
- Load unarchived Verifications from the DB.

Merit:
- Checkpoints.
- If a TX wasn't confirmed, but doesn't have any competitors, default it to confirmed.
- Improve the Difficulty algorithm.
- Dead Merit.
- Resolve Merit forks.
- Have cutoff Rewards carry over.
- Make RandomX the mining algorithm (node should use the 256 MB mode).
- Don't just hash the block header; include random sampling to force miners to run full nodes.
- Remove holders who lost all their Merit from `merit_holders`.

Verifications & Merit:
- Merit Removal.
- Currently, Blockchains archive Verifications via the tip; we should also add a start nonce to ignore unarchived Verifications which are past their Epoch.
- Verification Exclusions: Verifications that we can't find the TX for, so the Block says to ignore, which are validated by checkpoints.

Lattice:
- Cache the UXTO set.
- Have work precalculable for 100 `Send`'s/`Data`'s in advance.
- Difficulty voting.
- Lock boxes.

Network:
- Prevent the same client from connecting multiple times.
- Peer finding.
- Node karma.
- Multi-client syncing.
- Sync Entries not on the Blockchain.
- Sync Verifications not on the Blockchain.
- Sync gaps (if we get data with nonce 2 but we only have 0; applies to both the Lattice and Verifications).
- Replace the `sleepAsync(100)` in `verify` with gap syncing.
- Move Entries and Verifications to UDP.

### Tests:
objects:
- objects/Config Test.

lib:
- lib/Logger Test.

Wallet:
- Wallet/Ed25519 Test.
- Wallet/MinerWallet Test.
- Wallet/Wallet Test.

Database/Verifications:
- Database/Verifications/Verifier Test.
- Database/Verifications/Verification Test.

Database/Merit:
- Database/Merit/BlockHeader Test.
- Database/Merit/Block Test.
- Database/Merit/Difficulty Test.
- Database/Merit/Merit Test.
- Add DB writeups, like the one in the VerificationsTest, to BlockchainTest, StateTest, and EpochsTest.

Database/Lattice:
- Database/Lattice/Entry Test.
- Database/Lattice/Mint Test.
- Database/Lattice/Claim Test.
- Database/Lattice/Send Test.
- Database/Lattice/Receive Test.
- Database/Lattice/Data Test.
- Database/Lattice/Account Test.
- Clean the Database/Lattice/Lattice Test and test loading Verifications after 6 and 9 Blocks.

Network:
- Tests.

UI/RPC:
- UI/RPC/RPC Test.
- UI/RPC/Modules/SystemModule Test.
- UI/RPC/Modules/VerificationsModule Test.
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
- Expose more of the Verifications RPC.

- Loading screen.
- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:
- Edit Status's Milagro wrapper to use the same curve as Chia and update mc_bls to use that.

### Documentation:
- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Document the Message Types under `docs/Protocol`.
- Use Nim Documentation Comments.
- Meros Whitepaper.
