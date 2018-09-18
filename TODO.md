# TODO

Core:
- Rest of the parse functions.
- Track Verifications.
- Track MeritRemovals.
- Link the Lattice to Merit.
- UI.
- Filesystem.
- Difficulty Vote node.
- Fork resolution for blocks of different types.
- Finish tests.

Features:
- Chain Params file.
- Have Merit disappear after 50000 (365.25\*24\*6 is 52596; just rounded down for ease) blocks.
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
- Remove GMP's memory leak.

Documentation:
- Add comments to:
    - DB/Merit/State.nim

    - Wallet/Wallet.nim
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
