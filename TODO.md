# TODO

Core:
- Track Verifications.
- Link the Lattice to Merit.
- Track MeritRemovals.
- UI.
- Filesystem.
- Difficulty Vote node.
- Fork resolution for blocks of different types.
- Finish tests.
- Move Verifications out of the Lattice and onto the blockchain with BLS.

Features:
- Implement Bech32's BCH codes into Address.nim.
- Chain Params file.
- Have Merit Holders indexable by the order they got Merit in.

Improvements:
- Use custom errors.
- Replace awaits with yields.
- Make Miners/Validations proper objects.
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Optimize serialize/parse.
- Rewrite GMP package (last update was 2015).
- Don't have BN round down; have it round to the closest number.

Behavior Changes:
- Have required work be based on account, not that TX, and infinitely precalculable.
- Finalize Argon2's Block parameters.

Bug fixes:
- On Windows, the Network accepts a single Client and then only handles it, instead of also accepting new ones.
- Fix trailing zeroes in Base32 seqs. As Base32 is only used for addresses, which works off a set length, this is not an issue which affects CURRENT usage in any way.
- Remove GMP's memory leak.

Documentation:
- Add comments to Wallet/Wallet.nim.
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
