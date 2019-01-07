# TODO

### Core:
- Verify BLS Public Keys.
- Improve the Difficulty algorithm.
- Inactive Merit.
- Have Merit Holders indexable by the order they got Merit in.
- Resolve Merit forks.
- Have cutoff Rewards carry over.

- SerializeVerifications.
- Update Syncing.
- Update RPC/docs.
- Tests.

- Make sure serialized elements are unique (data is just `!data.nonce.toBinary() & !data.data` which is a collision waiting to happen).
- Remove direct references to clients[0].
- Sync Entries not on the Blockchain.
- Sync Verifications not on the Blockchain.
- Sync gaps (if we get an Entry with nonce 8 but we only have up to 6; applies to both the Lattice and Verifications).
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

- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:
- Replace bools as status codes with Exceptions.
- Replace BLS/Sodium Errors when a signature fails, versus when the lib fails, with `SignatureError`.
- Add `DataExistsError` for when data has already been added.
- Replace `KeyError` (and `ValueError`s we've used as `KeyError`s) with `EmbIndexError`.
- Use `sugerror`'s `reraise` for all our Exception wrapping.

- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.
- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- Don't rebroadcast Blocks that we synced.
- Improve Network's encapsulation.

- Make more things `func`.

### Behavior Changes:
    Decided:
        - Have Sends/Datas SHA512 signed, not their Argon, so remote services can handle the work.
        - Have required work be based on account, not on TX, and infinitely precalculable.
        - Finalize Argon2's Block parameters.

    Undecided:
        - Don't push 255, 255, remainder for the length; push the amount of length bytes and then the raw binary (exponential over additive).
        - Have Verifications also use Ed25519/have BLS signatures be asked for.

### Documentation:
- If a piece of code had a GitHub Issue, put a link to the issue in a comment. Shed some light on the decision making process.
- Document the Message Types.
- Use Nim Documentation Comments.
- Ember Whitepaper.

### Community Service:
- Create a Nimble library out of ED25519.
