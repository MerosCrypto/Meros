# TODO

### Core:
Filesystem:
- Store Verifications.
- Store Blocks.
- Store Entries.

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

Tests:
- Merkle fuzz testing.
- Tests.

### Features:
- Command line options.
- Make the ports to listen on runtime options.

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
- Clean up the `ptr AggregationInfo` mess we have now.
- Edit Status's Milagro wrapper to use the same curve as Chia and update mc_bls to use that.

- Remove `EventError`.
- Add `DataExistsError` for when data has already been added.
- Replace `KeyError` (and `ValueError`s we've used as `KeyError`s) with `MerosIndexError`.
- Replace BLS/Sodium Errors when a signature fails, versus when the lib fails, with `SignatureError`.
- Replace every Error with Enums. Every function should return an Option-Esque EITHER Enum or Value and have a blank raises pragma.

- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.
- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- `verifications.getPendingAggregate` has a very specific use case and it should be merged with `verifications.getUnarchivedIndexes`.

- Clean `merit.addBlock`.
- Don't rebroadcast Blocks or Entries that we're syncing.

- Make more `proc`s `func`.

### Documentation:
- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Document the Message Types.
- Use Nim Documentation Comments.
- Meros Whitepaper.

### Community Service:
- Create a Nimble library out of our Ed25519 code (and remove LibSodium from the Meros repo).
