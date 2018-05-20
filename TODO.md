# TODO

- Clean up the order of functions in uint256
- Fix the 2x speed ups
- Port the code to UInt256
- Fix the if statement in Difficulty (L19)

- Add getters to Blockchain.nim
- State.nim
- Reputation.nim master class

- Dedicated miner
- Verify miner ID in Block.nim (public key/address scheme?)

- Have proof act as a salt of the SHA hash, not a part of the SHA hash
- Update Difficulty to use the salted SHA hash
- Move from SHA to Lyra2 (hash = password, proof = salt)
