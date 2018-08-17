# TODO

Core:
- Parse functions.
- Difficulty Vote node.
- Account, Lattice, and Database files.
- Filesystem code.
- Network.
- UI.
- Write tests for:
    - BN
    - SECP256K1Wrapper
    - SHA512

    - Address (mostly done)

    - Merkle
    - Block
    - Difficulty

    - Node
    - Transaction
    - Data
    - Verification
    - MeritRemoval

    - Serialize

Features:
- Have Merit disappear after 365.25\*24\*6 (52596) blocks.
- Threaded/dedicated miner.

Improvements:
- Use a faster BN lib.
- Optimize SECP256K1Wrapper (memory copies, splices...).

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

    - DB/Lattice/Verification.nim
    - DB/Lattice/Lattice.nim

    - DB/Database.nim

    - Wallet/PublicKey.nim
    - Wallet/Wallet.nim

    - UI/

    - tests/
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
