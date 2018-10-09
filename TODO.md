# TODO

Core:
- Redo `Block`s to use `Verification`s.
- Handle `Block`s over the `Network`.
- Handle `Block`s in `MainMerit`.

- Implement Bech32's BCH codes into `Address`.
- Have Merit Holders indexable by the order they got Merit in.

- Tell the GUI thread to close.

- `MeritRemoval` node.
- `Difficulty Vote` node.

- BLS.
- Enable the BLS part of `Verification`.
- Use `BLS` in `Block`s.

- Finish the Tests.

Features:
- `Account` history over the GUI.
- `Verification`s over the GUI.

- Have the RPC dynamically get the difficulty.
- Have every RPC method return something.
- Have the RPC send errors when it fails.

- Make the port to listen on a runtime option.

Improvements:
- Make nonce an `uint`.
- Make `miners` and `validations` proper objects.

- Replace `newBN(x).toString(256)` with bit shifts under `Util.nim`.
- Optimize `serialize` and `parse`.

- Standardize where we use binary/hex/addresses.

- Make more things `func`.
- Make sure `KeyError` is listed under `raises`.

Behavior Changes:
- Have required work be based on account, not that TX, and infinitely precalculable.
- Finalize Argon2's Block parameters.

Bug fixes:
- Receives from "minter" can't be broadcasted across the network.
- Remove GMP's memory leak.
- Fix trailing zeroes in Base32 seqs. This is due to right padding the result instead of left padding them. As Base32 is only used for addresses, which works off a set length, this is not an issue which affects CURRENT usage in any way.
- Tests still fail with some edge cases. This is likely due to missing pads.

Documentation:
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon.
- Create a Nimble library out of ED25519.
