# TODO

Core:
- Add signatures to Blocks.
- Have a way for the network to set difficulty.
- Lattice.
- UI.
- DB.
- Network.
- Write tests for:
    - BN
    - SECP256K1Wrapper
    - SHA512

    - Address (mostly done)

    - Merkle
    - Block
    - Difficulty

    - Signature
    - Transaction

Features:
- Add Merit decay.
- Threaded mining.
- Dedicated miner.

Bug fixes and behavior changes:
- Use a faster BN lib.
- Fix Argon2 parameters.
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Remove as many uses of the generic `Exception` as possible.

Documentation:
- Add comments to:
    - lib/Base.nim

    - Merit/Merkle.nim
    - Merit/State.nim

    - Wallet/PublicKey.nim
    - Wallet/Wallet.nim

    - Lattice/Signature.nim
    - Lattice/Lattice.nim

    - UI/
    - DB/
    - Network/

    - tests/
- Use Documentation Comments.
- Merit Caching Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
