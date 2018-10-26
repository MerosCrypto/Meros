# TODO

### Core:
- Auto-Receive/Claim.
- Miner.

- Verify BLS Public Keys.
- Inactive Merit.
- Have Merit Holders indexable by the order they got Merit in.
- Resolve Merit forks.

- EMB Minting.
- Resolve Lattice forks (right now, unverified Nodes are treated as Verified...).

- Handshake when connecting to Nodes.
- Ask for missing data (syncing).
- Handle Claims over the Network.

- Make sure serialized elements are unique (data is just `!data.nonce.toBinary() & !data.data` which is a collision waiting to happen).
- Merit Removal system.
- Difficulty Voting system.

- Database.

- Utilize Logger.
- Check Signatures in Serialize Tests.
- Tests.

### Features:
- Only add meaningful verifications.
- Only verify if you actually have Merit; not just if you're Mining.

- Command line options.

- Have `Logger.urgent` open a dialog box.

- RPC creation of Claims.
- Have the RPC dynamically get the difficulty.

- Show the existing wallet on reload of `Main.html`.
- Claim creation via the GUI.
- `Account` history viewing via the GUI.
- Network page on the GUI.

- Make `Logger.extraneous` enabled via a runtime option.
- Make the ports to listen on runtime options.

### Improvements:
- Redo how Blocks are handled (monolithic constructors; start block mess; no `Block.sign()`).

- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- Move `SerializeVerifications` and `ParseVerifications` out of `SerializeBlock`/`ParseBlock`.
- Optimize the speed of `serialize` and `parse`.
- Stop whatever's causing series of unneeded 0s in serialized objects.

- Standardize where we use binary/hex/addresses in `Database/Lattice`.

- Make more things `func`.
- Remove `{.gcsafe.}`.
- Make sure `KeyError` is listed under `raises`.

### Behavior Changes:

    Decided:
        - Have required work be based on account, not on TX, and infinitely precalculable.
        - Finalize Argon2's Block parameters.

    Undecided:
        - Have Verifications also use Ed25519/have BLS signatures be asked for.

### Documentation:
- Document the message types.
- Document the RPC.
- Use Documentation Comments.
- Ember Whitepaper.

### Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon.
- Create a Nimble library out of ED25519.
