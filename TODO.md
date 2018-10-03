# TODO

Core:
- Have every RPC method return something.
- Have the RPC send errors when it fails.

- Broadcast Lattice entries created over the RPC.

- Track Verifications.
- Link the Lattice to Merit.
- Track MeritRemovals.
- Difficulty Vote node.
- Fork resolution for blocks of different types.

- Move Verifications out of the Lattice and onto the blockchain with BLS.

- Filesystem.
- Finish tests.

Features:
- Implement Bech32's BCH codes into Address.nim.
- Have Merit Holders indexable by the order they got Merit in.

Improvements:
- Tell the GUI thread to close.

- Have Wallet use Key Pairs over Private Keys.
- Make sure we aren't signing hex strings but their raw binary versions.

- Make Miners/Validations proper objects.
- Optimize serialize/parse.
- Optimize SECP256K1Wrapper (memory copies, splices...).

- Use the effects system with async.
- Use custom errors.

- Chain Params file.

Behavior Changes:
- Have required work be based on account, not that TX, and infinitely precalculable.
- Finalize Argon2's Block parameters.

Bug fixes:
- Receives from "minter" can't be broadcasted across the network.
- Remove GMP's memory leak.
- Fix trailing zeroes in Base32 seqs. As Base32 is only used for addresses, which works off a set length, this is not an issue which affects CURRENT usage in any way.

Documentation:
- Add comments to Wallet/Wallet.nim.
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon.
- Create a Nimble library out of libsodium.
