# TODO

Core:
- Write tests.

Features:
- Add Merit decay.
- Threaded mining.
- Dedicated miner.
- Hex string to byte array and vice versa.

Bug fixes and behavior changes:
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).
- PrivateKey's secret property is public.
- Multiple uses of the generic `Exception`.
- Optimize SECP256K1Wrapper (memory copies, splices...).


Documentation:
- Add comments to:
    - lib/Base58.nim
    - lib/Hex.nim

    - Merit/State.nim
    - Merit/Merit.nim

    - Wallet/PrivateKey
    - Wallet/PublicKey
    - Wallet/Wallet
- Merit Caching Whitepaper.

Community Service:
- Create a Nimble library out of BN.
- Create a Nimble library out of Base58/Hex.
- Create a Nimble library out of Lyra2.
