# TODO

### Core:
- Verify BLS Public Keys.
- Improve the Difficulty algorithm.
- Inactive Merit.
- Have Merit Holders indexable by the order they got Merit in.
- Resolve Merit forks.

- Resolve Lattice forks (right now, unverified Nodes are treated as Verified when it comes to their permeance...).

- Handshake when connecting to Nodes.
- Ask for missing data (syncing).
- Make sure serialized elements are unique (data is just `!data.nonce.toBinary() & !data.data` which is a collision waiting to happen).
- Make sure there's no leading bytes in serialized elements.

- Merit Removal system.
- Difficulty Voting system.

- Database.

- SerializeVerifications Test (we only test Verification serializing; not Verifications).
- SerializeBlock Test.
- Tests.

- Test Minting/Auto-Claim/Auto-Receive (requires a test network).

### Features:
- Command line options.
- Make the ports to listen on runtime options.

- Utilize Logger.
- Have `Logger.urgent` open a dialog box.
- Make `Logger.extraneous` enabled via a runtime option.

- Have RPC handle things in order OR use an ID system.
- RPC creation of Claims.
- Have the RPC dynamically get the mining difficulty (it's currently hardcoded).

- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

### Improvements:
- We route all of Ed25519 through Wallet. We have MinerWallet. We frequently use BLS directly. Remedy this.
- Improve Network's encapsulation.

- Merkle Tree appending.

- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- Move `SerializeVerifications` and `ParseVerifications` out of `SerializeBlock`/`ParseBlock`.
- Optimize the speed of `serialize` and `parse` (reserializing every parsed element?).
- Stop whatever's causing series of unneeded 0s in serialized objects.

- Standardize where we use binary/hex/addresses in `Database/Lattice`.

- Make more things `func`.
- Make sure `KeyError` is listed under `raises`.

### Behavior Changes:
    Decided:
        - Have required work be based on account, not on TX, and infinitely precalculable.
        - Finalize Argon2's Block parameters.

    Undecided:
        - Have Verifications also use Ed25519/have BLS signatures be asked for.

### Documentation:
- Document the message types.
- Use Nim Documentation Comments.
- Ember Whitepaper.

### Community Service:
- Create a Nimble library out of ED25519.
