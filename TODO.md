# TODO

Core:
- Reputation.nim (master class of Blockchain/State).
- Wallet.nim (master class of PrivateKey/PublicKey/Address).
- Write tests.

Features:
- Add State halving.
- Add State decay.
- Dedicated miner.

Bug fixes and behavior changes:
- Smooth difficulty scaling (difficulty may also only be rescaling on block mining; this is inefficient).

Documentation:
- Add comments to:
    lib/Base58.nim
    lib/Hex.nim
    lib/SECP256K1Wrapper.nim

    Reputation/Blockchain.nim
    Reputation/Difficulty.nim
    Reputation/State.nim

    Wallet/PrivateKey
    Wallet/PublicKey

    samples/addressGenerator.nim
- Write a README.

Community Service:
- Create a Nimble library out of BN.
- Create a Nimble library out of Base58/Hex.
- Create a Nimble library out of Lyra2.
