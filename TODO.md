# TODO

Core:
- Write tests.

Features:
- Add Reputation decay.
- Threaded mining.
- Dedicated miner.

Bug fixes and behavior changes:
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).
- PrivateKey's secret property is public.
- SHA512 uses the generic Exception.

Documentation:
- Add comments to:
    - lib/Base58.nim
    - lib/Hex.nim
    - lib/SECP256K1Wrapper.nim

    - Reputation/Blockchain.nim
    - Reputation/Difficulty.nim
    - Reputation/State.nim
    - Reputation/Reputation.nim

    - Wallet/PrivateKey
    - Wallet/PublicKey
    - Wallet/Wallet
- Merit Caching Whitepaper.

Community Service:
- Create a Nimble library out of BN.
- Create a Nimble library out of Base58/Hex.
- Create a Nimble library out of Lyra2.
