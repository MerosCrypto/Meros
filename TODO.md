# TODO

Core:
- Have the RPC dynamically get the difficulty.
- Have every RPC method return something.
- Have the RPC send errors when it fails.

- Track Verifications.
- Link the Lattice to Merit.
- Track MeritRemovals.
- Difficulty Vote node.
- Fork resolution for blocks of different types.

- Have Verifications take a Ed25519 sig and a BLS sig.
- Move Verifications off of the Lattice into memory.
- Finalize Verifications on the blockchain with BLS.

- Filesystem.
- Finish tests.

Features:
- Implement Bech32's BCH codes into Address.nim.
- Have Merit Holders indexable by the order they got Merit in.

Improvements:
- Make more things `func`.

- Tell the GUI thread to close.

- Standardize where we use binary/hex/addresses.

- Make Miners/Validations proper objects.
- Optimize serialize/parse.

- Remove blocksPerMonth.
- Make the port to listen on a runtime option.

Behavior Changes:
- Have required work be based on account, not that TX, and infinitely precalculable.
- Finalize Argon2's Block parameters.

Bug fixes:
- Receives from "minter" can't be broadcasted across the network.
- Remove GMP's memory leak.
- Fix trailing zeroes in Base32 seqs. This is due to right padding the result instead of left padding them. As Base32 is only used for addresses, which works off a set length, this is not an issue which affects CURRENT usage in any way.

Documentation:
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon.
- Create a Nimble library out of ED25519.
