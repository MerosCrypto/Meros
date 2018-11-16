# TODO

### Core:
- Verify BLS Public Keys.
- Improve the Difficulty algorithm.
- Inactive Merit.
- Have Merit Holders indexable by the order they got Merit in.
- Resolve Merit forks.
- Have cutoff Rewards carry over.

- Make sure serialized elements are unique (data is just `!data.nonce.toBinary() & !data.data` which is a collision waiting to happen).
- Make sure there's no leading bytes in serialized elements.
- Remove Network ID/Protocol version from the Header since they're in the Handshake.
- Remove direct references to clients[0].
- Add Node karma.

- Merit Removal system.
- Difficulty Voting system.

- Database.

- Tests.

### Features:
- Command line options.
- Make the ports to listen on runtime options.

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

- Have RPC handle things in order OR use an ID system.
- RPC creation of Claims.
- Have the RPC dynamically get the mining difficulty (it's currently hardcoded).
- Have the RPC dynamically get the nonce (it's currently an argument).
- RPC getEntry using an index.

- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:
- Use sugerror's reraise for all our Exception wrapping.

- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.
- Merkle Tree appending.
- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- Stop duplicate Clients.
- Don't rebroadcast Blocks that we synced.
- Use requestBlock in the Handshake.
- Improve Network's encapsulation.

- Make more things `func`.
- Make sure `KeyError` is listed under `raises`.

### Behavior Changes:
    Decided:
        - Have Sends/Datas SHA512 signed, not their Argon, so remote services can handle the work.
        - Have required work be based on account, not on TX, and infinitely precalculable.
        - Finalize Argon2's Block parameters.

    Undecided:
        - Don't push 255, 255, remainder for the length; push the amount of length bytes and then the raw binary (exponential over additive).
        - Have Verifications also use Ed25519/have BLS signatures be asked for.

### Documentation:
- Document the Message Types.
- Use Nim Documentation Comments.
- Ember Whitepaper.

### Community Service:
- Create a Nimble library out of ED25519.
