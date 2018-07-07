# TODO

Core:
- Write tests.

Features:
- Add State halving.
- Add State decay.
- Dedicated miner.

Bug fixes and behavior changes:
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).
- PrivateKey's secret property is public.

Documentation:
- Add comments to:
    lib/Base58.nim
    lib/Hex.nim
    lib/SECP256K1Wrapper.nim

    Reputation/Blockchain.nim
    Reputation/Difficulty.nim
    Reputation/State.nim
    Reputation/Reputation.nim

    Wallet/PrivateKey
    Wallet/PublicKey
    Wallet/Wallet

    samples/addressGenerator.nim
- Write a README.

Community Service:
- Create a Nimble library out of BN.
- Create a Nimble library out of Base58/Hex.
- Create a Nimble library out of Lyra2.
