# TODO

Core:
- Write tests.
- Use custom errors.
- Fix GMP memory leak.
- Write a Lattice/Database State.
- Parse functions (which requires knowing the state).
- Difficulty Vote node.
- Account, Lattice, and Database files.
- Filesystem code.
- Network.
- UI.

Features:
- Have Merit disappear after 365.25\*24\*6 (52596) blocks.
- Have Merit Holders indexable by the order they got Merit in.
- Threaded/dedicated miner.

Improvements:
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Rewrite GMP package (last update was 2015).

Bug fixes and behavior changes:
- Put object definitions into dedicated files.
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).
- Remove as many uses of the generic `Exception` as possible.
- Standardize error messages.
- Finalize Argon2 parameters.

Documentation:
- Add comments to:
    - lib/Base.nim

    - DB/Merit/Merkle.nim
    - DB/Merit/State.nim

    - DB/Lattice/Lattice.nim

    - DB/Database.nim
    - DB/State.nim

    - Wallet/PublicKey.nim
    - Wallet/Wallet.nim
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
