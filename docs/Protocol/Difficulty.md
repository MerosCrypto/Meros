# Difficulty

Meros's difficulty is heavily inspired from Cryptonote. Difficulty is represented as an unsigned 64-bit integer where `difficulty / 2 + 1` is the average amount of hashes needed to beat it. In the case of Sends, Datas, and Unlocks, difficulty is represented as an unsigned 32-bit integer.

# Spam Function

The spam function is takes in a Transaction's hash and proof, as well as the difficulty to check against. It returns a boolean of whether or not the Transaction is spam.

```
max = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

def spam(
    hash: bytes,
    proof: bytes,
    difficulty: int
) -> bool:
    return Argon2d(
        iterations = 1,
        memory = 8,
        parallelism = 1,
        data = hash,
        salt = proof left padded to be 8 bytes long
    ) * difficulty <= max
```

# Send Difficulty

The Send difficulty is initially set to 3 and is decided as described in the Consensus documentation.

In order for a Send's proof to beat the difficulty, the following check must pass:

```
factor = (70 + (33 * amount of inputs) + (40 * amount of outputs)) / 70
spam(hash, proof, sendDifficulty * factor)
```

# Data Difficulty

The Data difficulty is initially set to 5 and is decided as described in the Consensus documentation.

In order for a Data's proof to beat the difficulty, the following check must pass:

```
factor = (101 + data.length) / 101
spam(hash, proof, dataDifficulty * factor)
```

# Gas Difficulty

The Gas difficulty is initially set to 8 and is decided as described in the Consensus documentation.

In order for a Unlock's proof to beat the difficulty, the following check must pass:

```
spam(hash, proof, gasDifficulty * usedGas)
```

# Blockchain Difficulty

The Blockchain difficulty is initially set to 10,000,000. When the third Block after the genesis is added, the difficulty starts updating every Block.

A window of Blocks is selected, including the newest Block. The window has a variable size depending on how long the Blockchain is.

- If the Blockchain height is less than 1008 (first week), the amount of Blocks used in the window is 3.
- If the Blockchain height is less than 4320 (first month), the amount of Blocks used in the window is 18.
- If the Blockchain height is less than 12960 (first three months), the amount of Blocks used in the window is 36.
- If the Blockchain height is less than 25920 (first six months), the amount of Blocks used in the window is 72.
- If the Blockchain height is less than 52560 (first year), the amount of Blocks used in the window is 144.

The `window.length / 10` Blocks with the most outlying difficulties from the median are removed from the window.

The new difficulty is defined as `sum(windowDifficulties) * 600 / (window[window.length - 1].header.time - window[1].header.time)`, where 600 represents the Block time.

### Violations in Meros

- Meros uses a 256-bit difficulty for the Blockchain.
- Meros has a different initial Blockchain difficulty.
- Meros uses a different amount of Blocks in the window depending on how long the Blockchain is.
- Meros doesn't remove outlying difficulties from the Blockchain's window.
- Meros uses a different formula to calculate the Blockchain's next difficulty.
- Meros uses a different formula to verify the Blockchain's difficulty.
