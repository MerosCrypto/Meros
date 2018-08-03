# TODO

Core:
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

    - Block
    - Difficulty

    - Node

Features:
- Add Merit decay.
- Threaded mining.
- Dedicated miner.

Bug fixes and behavior changes:
- Fix imath on Linux/integrate GMP.
- Fix Argon2 Memory parameter.
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Remove as many uses of the generic `Exception` as possible.

Documentation:
- Add comments to:
    - lib/Base.nim

    - Merit/State.nim

    - Wallet/PublicKey.nim
    - Wallet/Wallet.nim

    - Lattice/Lattice.nim
    - Lattice/Nodechain.nim

    - UI/
    - DB/
    - Network/

    - tests/
- Use Documentation Comments.
- Merit Caching Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
