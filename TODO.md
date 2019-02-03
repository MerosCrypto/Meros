# TODO

### Core:
- Improve the Difficulty algorithm.
- Dead Merit.
- Have Merit Holders indexable by the order they got Merit in.
- Resolve Merit forks.
- Have cutoff Rewards carry over.

- Make sure hash sources are unique (data is just `data.data` which is a collision waiting to happen).
- Multi-client syncing.
- Sync Entries not on the Blockchain.
- Sync Verifications not on the Blockchain.
- Sync gaps (if we get data with nonce 8 but we only have up to 6; applies to both the Lattice and Verifications).
- Replace the `sleepAsync(100)` in `verify` for gap syncing.
- Add peer finding.
- Add Node karma.

- Merit Removal system.
- Difficulty Voting system.

- Database.

- Merkle fuzz testing.
- Tests.

### Features:
- Command line options.
- Make the ports to listen on runtime options.

- Don't allow the same Client to connect multiple times.

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

- Have RPC handle things in order OR use an ID system.
- Have the RPC dynamically get the nonce (it's currently an argument).
- `network.rebroadcast(address, nonce)` RPC method.
- Expose more of the Verifications RPC.

- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:
- Switch from Chia's BLS lib to Milagro, yet keep mc_bls so we can preserve most of the API.
- When we switch to Milagro, clean up the `ptr AggregationInfo` mess we have now.

- Clean `merit.addBlock`.

- Remove `EventError`.
- Add `DataExistsError` for when data has already been added.
- Replace `KeyError` (and `ValueError`s we've used as `KeyError`s) with `MerosIndexError`.
- Replace BLS/Sodium Errors when a signature fails, versus when the lib fails, with `SignatureError`.
- Use `sugerror`'s `reraise` for all our Exception wrapping.
- Clean up all the `try`s/`except`s/`raises` in the RPC.
- Solve bool/exception disparity by replacing most bools with Exceptions.

- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.
- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- `verifications.getPendingAggregate` has a very specific use case and it should be merged with `verifications.getUnarchivedIndexes`.

- Don't rebroadcast Blocks or Entries that we're syncing.

- Make more things `func`.

### Behavior Changes:
    Decided:
        - Have Sends/Datas SHA512 signed, not their Argon, so remote services can handle the work.
        - Have required work be based on account, not on TX, and precalculable to a point.
        - Replace Argon2d with a CPU-only algorithm.

    Undecided:
        - Use Ed25519 everywhere; BLS saves space but since we handle the Verifications when they come in, it doesn't save time.
        - Don't push 255, 255, remainder for the length; push the amount of length bytes and then the raw binary (exponential over additive).

### Documentation:
- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Document the Message Types.
- Use Nim Documentation Comments.
- Meros Whitepaper.

### Community Service:
- Create a Nimble library out of Ed25519.
