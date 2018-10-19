# TODO

### Core:
- Verify BLS Public Keys.
- Have Merit Holders indexable by the order they got Merit in.
- Miner.

- Minting.
- `MinterReceive` node.

- Merit Removal system.
- Difficulty Voting system.

- Database.

- Utilize logging.
- Finish the Tests.

### Features:
- Have `Logger.urgent` open a dialog box.

- Show the existing wallet on reload of `Main.html`.
- `Account` history over the GUI.
- `Verification`s over the GUI.

- Have the RPC dynamically get the difficulty.

- Make `Logger.extraneous` enabled via a runtime option.
- Make the ports to listen on runtime options.

### Improvements:
- Make `newMinerWallet` take a Private Key; not a string.

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

### Bug fixes:

    Wallet:
        - Base32 seqs sometimes have trailing 0s. This is due to right padding the result instead of left padding it. This is not an issue which affects CURRENT usage in any way.
        - `Address.toBN()` occasionally returns the wrong BN.

    Network:
        - Networking code breaks across different endians.

    Other:
        - GMP has a memory leak.

### Documentation:
- Document the message types.
- Document the RPC.
- Use Documentation Comments.
- Ember Whitepaper.

### Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon.
- Create a Nimble library out of ED25519.
