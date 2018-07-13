# TODO

Core:
- Lattice.
- UI.
- DB.
- Network.
- Write tests besides Base58.

Features:
- Add Merit decay.
- Threaded mining.
- Dedicated miner

Bug fixes and behavior changes:
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Clean up raises.
- Switch some ValueErrors to RaiseErrors.
- Multiple uses of the generic `Exception`.

Documentation:
- Add comments to:
    - lib/Base58.nim
    - lib/Hex.nim

    - Merit/State.nim
    - Merit/Merit.nim

    - Wallet/PrivateKey
    - Wallet/PublicKey
    - Wallet/Wallet

    - Lattice/
    - UI/
    - DB/
    - Network/
- Use Documentation Comments.
- Merit Caching Whitepaper.

Community Service:
- Create a Nimble library out of BN.
- Create a Nimble library out of Base58/Hex.
- Create a Nimble library out of Lyra2.
