# TODO

### Core:
- Update BLS to handle AggregationInfos properly, instead of offloading pointer work.
- Update Verifications to use Ed25519 Public Key + nonce, instead of the hash. 28 byte savings + gap detection while syncing.
- Update Claims to use Ed25519 Public Keys, not addresses.

- Improve the Difficulty algorithm.
- Inactive Merit.
- Have Merit Holders indexable by the order they got Merit in.
- Resolve Merit forks.
- Have cutoff Rewards carry over.

- Make sure hash sources are unique (data is just `data.data` which is a collision waiting to happen).
- Remove direct references to clients[0].
- Sync Entries not on the Blockchain.
- Sync Verifications not on the Blockchain.
- Sync gaps (if we get an Entry with nonce 8 but we only have up to 6; applies to both the Lattice and Verifications).
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
- Replace bools as status codes with Exceptions.
- Replace BLS/Sodium Errors when a signature fails, versus when the lib fails, with `SignatureError`.
- Add `DataExistsError` for when data has already been added.
- Replace `KeyError` (and `ValueError`s we've used as `KeyError`s) with `MerosIndexError`.
- Use `sugerror`'s `reraise` for all our Exception wrapping.

- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.
- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- Optimize `verifier.calculateMerkle()` by having every Verifier keep track of their own Merkle, and just cutting off the tail.
- `verifications.getPendingAggregate` has a very specific use case and it should be merged with `verifications.getUnarchivedIndexes`.

- Don't rebroadcast Blocks that we're syncing.
- Improve Network's encapsulation.

- Make more things `func`.

### Behavior Changes:
    Decided:
        - Have Sends/Datas SHA512 signed, not their Argon, so remote services can handle the work.
        - Have required work be based on account, not on TX, and precalculable to a point.
        - Replace Argon2.

    Undecided:
        - Use ED25519 everywhere; BLS saves space but since we handle the Verifications when they come in, it doesn't save time.
        - Don't push 255, 255, remainder for the length; push the amount of length bytes and then the raw binary (exponential over additive).

### Documentation:
- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Document the Message Types.
- Use Nim Documentation Comments.
- Meros Whitepaper.

### Community Service:
- Create a Nimble library out of ED25519.
