# TODO

Core:
- Add in Chia's BLS lib.
- Properly use the signature field of `Verifications`.

- Handle `Block`s over the `Network`.
- Handle `Block`s in `MainMerit`.

- Have Merit Holders indexable by the order they got Merit in.

- Tell the GUI thread to close.

- `MeritRemoval` node.
- `Difficulty Vote` node.

- Finish the Tests.

Features:
- Logging.

- Show the existing wallet on reload of `Main.html`.
- `Account` history over the GUI.
- `Verification`s over the GUI.

- Have the RPC dynamically get the difficulty.

- Make the ports to listen on runtime options.

Improvements:
- Remove extraneous uints from Lattice.

- Replace `newBN(x).toString(256)` with bit shifts under `Util.nim`.
- Optimize `serialize` and `parse`.

- Move `SerializeVerifications` and `ParseVerifications` out of `SerializeBlock`/`ParseBlock`.

- Standardize where we use binary/hex/addresses.

- Make more things `func`.
- Make sure `KeyError` is listed under `raises`.

Behavior Changes:
- Have required work be based on account, not that TX, and infinitely precalculable.
- Finalize Argon2's Block parameters.

Bug fixes:
- Receives from "minter" can't be broadcasted across the network.
- Remove GMP's memory leak.
- Ember will crash if sent a JSON array that's too short.
- Fix trailing zeroes in Base32 seqs. This is due to right padding the result instead of left padding them. This is not an issue which affects CURRENT usage in any way.
- Tests still fail with some edge cases. This is likely due to missing pads.

Documentation:
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon.
- Create a Nimble library out of ED25519.
