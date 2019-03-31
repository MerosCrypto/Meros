# TODO

### DB Branch Before Merge:
- We save Entries to `lattice_HASH`.
- We save confirmed, including Mint, hashes to `lattice_SENDER_NONCE`.
- We save a list of accounts.
- We need to load the list of accounts.
- We need to provide access to confirmed Entries in the DB.
- We need to reload the last 6 blocks, resyncing the unconfirmed Entries and tracking the Verifications.

- Lattice Test (in relation to the DB).

### Core:
Verifications:
- Load unarchived verifications from the DB.
- Have one Merkle per Verifier per Block mention, not one Merkle per Verifier.
- When we load a Merkle, load every leaf into a seq, and then call newMerkle. Don't use addition.

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

Wallet:
- Mnemonic file to convert a Mnemonic to seed, and vice versa.
- HDWallet type which meets the specs defined in https://cardanolaunch.com/assets/Ed25519_BIP.pdf and creates Wallets.

Network:
- Move to fixed length messages (instead of length prefixes like we have now).
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
- lib/Base (256) Test.
- lib/Hash/Argon Test.
- lib/Hash/Blake2 Test.
- lib/Ed25519 Test.

Wallet:
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
- Database/Lattice/Lattice Test.

Network:
- Tests.

Network/Serialize/Lattice:
- Network/Serialize/Lattice/Entry Test.

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

- Have the RPC match the JSON-RPC 2.0 spec (minus HTTP).
- Have the RPC dynamically get the nonce (it's currently an argument).
- `network.rebroadcast(address | verifier, nonce)` RPC method.
- Expose more of the Verifications RPC.

- Loading screen.
- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:
- We used `uint` because indexes can't be negative and it was safer. That said, the constant casting is quite annoying and we're still limited to the `int` limits. In some places, we've even updated the casts to accept both, defeating the point. We should just remove `uint` at this point.

- Remove `ref` from objects that shouldn't be `ref`.
- Remove `of RootObj` from objects that aren't inherited from.

- Make more `proc`s `func`.

- Remove `EventError`.
- Rename the exported `LMDBError` to `DBError`.
- Add `DataExistsError` for when data has already been added.
- Replace `KeyError` (and `ValueError`s we've used as `KeyError`s) with `MerosIndexError`.
- Replace BLS/Sodium Errors when a signature fails, versus when the lib fails, with `SignatureError`.
- Clean up Exceptions, whether it be with Option-esque Enum code or something else.

- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- If a Merkle's left is too big to prune, or isn't full, descend until we find a left which isn't too big and is full.

- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.

- Edit Status's Milagro wrapper to use the same curve as Chia and update mc_bls to use that.

- `verifications.getPendingAggregate` has a very specific use case and it should be merged with `verifications.getUnarchivedIndexes`.

- Clean `merit.addBlock`.
- Don't rebroadcast Blocks or Entries that we're syncing.
- Pass difficulties to the parsing functions to immediately check if work was put into a Block/Entry (stop DoS attacks).

### Documentation:
- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Document the Message Types under `docs/Protocol`.
- Use Nim Documentation Comments.
- Meros Whitepaper.

### Community Service:
- Create a Nimble library out of our Ed25519 code (and remove LibSodium from the Meros repo).
