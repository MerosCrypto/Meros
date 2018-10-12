# TODO

### Core:
- Utilize logging.

- Add in Chia's BLS lib.
- Properly use the signature field of `Verifications`.

- Handle `Block`s over the `Network`.
- Handle `Block`s in `MainMerit`.

- Have Merit Holders indexable by the order they got Merit in.

- `MeritRemoval` node.
- `Difficulty Vote` node.

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
- Replace Base (currently B16 and B256) with Hex and merge B256 in with BN.

- Rename `Serialize` `$`.
- Move `SerializeVerifications` and `ParseVerifications` out of `SerializeBlock`/`ParseBlock`.
- Optimize the speed of `serialize` and `parse`.
- Stop whatever's causing series of unneeded 0s in serialized objects.

- Standardize where we use binary/hex/addresses.

- Make more things `func`.
- Make sure `KeyError` is listed under `raises`.

### Behavior Changes:
- Have required work be based on account, not that TX, and infinitely precalculable.
- Finalize Argon2's Block parameters.

### Bug fixes:

    Wallet:
        - Base32 seqs sometimes have trailing 0s. This is due to right padding the result instead of left padding it. This is not an issue which affects CURRENT usage in any way.
        - `Address.toBN()` occasionally returns the wrong BN.

    Network:
        - Receives from "minter" can't be broadcasted across the network.

    UI:
        - Ember crashes when the RPC gets a JSON array that's too short.

    Other:
        - GMP has a memory leak.

### Documentation:
- Use Documentation Comments.
- Ember Whitepaper.

### Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon.
- Create a Nimble library out of ED25519.
