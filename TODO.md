# TODO

### Core:
Filesystem:
- Store the last 6 blocks of Verifications in RAM, not just the last block.
- Load unarchived verifications.

- DB - Entries.

Verifications:
- Merit Removal.

Merit:
- Improve the Difficulty algorithm.
- Dead Merit.
- Resolve Merit forks.
- Have cutoff Rewards carry over.
- Make RandomX the mining algorithm (node should use the 256 MB mode).
- Don't just hash the block header; include random sampling to force miners to run full nodes.

Lattice:
- Have work precalculable for 100 `Send`'s/`Data`'s in advance.
- Difficulty voting.
- Lock boxes.

Wallet:
- Mnemonic file to convert a Mnemonic to seed, and vice versa.
- HDWallet type which meets the specs defined in https://cardanolaunch.com/assets/Ed25519_BIP.pdf and creates Wallets.

Network:
- Prevent the same client from connecting multiple times.
- Sync Entries not on the Blockchain.
- Sync Verifications not on the Blockchain.
- Sync gaps (if we get data with nonce 2 but we only have 0; applies to both the Lattice and Verifications).
- Replace the `sleepAsync(100)` in `verify` with gap syncing.
- Peer finding.
- Multi-client syncing.
- Node karma.
- Move Entries and Verifications to UDP.

### Tests:
lib:
- lib/Base (256) test.
- lib/Hash/Argon test.
- lib/Hash/Blake2 test.
- Merkle fuzz testing.
- lib/Ed25519 test.

Wallet:
- Wallet/MinerWallet test.
- Wallet/Wallet test.

Database/Verifications:
- Database/Verifications/Verifier test.
- Database/Verifications/Verification test.
- Database/Verifications/Verifications test.

Database/Merit:
- Database/Merit/Difficulty test.
- Database/Merit/Block test.
- Database/Merit/Blockchain test.
- Database/Merit/State test.
- More Database/Merit/Epochs test.
- Database/Merit/Merit test.

Database/Lattice:
- Database/Lattice/Entry test.
- Database/Lattice/Mint test.
- Database/Lattice/Claim test.
- Database/Lattice/Send test.
- Database/Lattice/Receive test.
- Database/Lattice/Data test.
- Database/Lattice/Account test.
- Database/Lattice/Lattice test.

Network:
- Tests.

Network/Serialize:
- Network/Serialize/Lattice/Entry test.

RPC:
- Tests.

Other:
- Config test.

### Features:
- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

- Have the RPC match the JSON-RPC 2.0 spec (minus HTTP).
- Have the RPC dynamically get the nonce (it's currently an argument).
- `network.rebroadcast(address, nonce)` RPC method.
- Expose more of the Verifications RPC.

- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:
- Edit Status's Milagro wrapper to use the same curve as Chia and update mc_bls to use that.

- Remove `EventError`.
- Add `DataExistsError` for when data has already been added.
- Replace `KeyError` (and `ValueError`s we've used as `KeyError`s) with `MerosIndexError`.
- Replace BLS/Sodium Errors when a signature fails, versus when the lib fails, with `SignatureError`.
- Clean up Exceptions, whether it be with Option-esque Enum code or something else.

- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.
- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- `verifications.getPendingAggregate` has a very specific use case and it should be merged with `verifications.getUnarchivedIndexes`.

- Clean `merit.addBlock`.
- Don't rebroadcast Blocks or Entries that we're syncing.

- Make more `proc`s `func`.

### Documentation:
- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Document the Message Types under `docs/Protocol`.
- Use Nim Documentation Comments.
- Meros Whitepaper.

### Community Service:
- Create a Nimble library out of our Ed25519 code (and remove LibSodium from the Meros repo).
