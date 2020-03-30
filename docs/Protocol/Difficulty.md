# Difficulty

Meros's difficulty is heavily inspired from Cryptonote. Difficulty is represented as an unsigned 64-bit integer where `difficulty / 2 + 1` is the average amount of hashes needed to beat it. In the case of Sends, Datas, and Unlocks, difficulty is represented as an unsigned 32-bit integer.

# Spam Function

The spam function takes in a Transaction's hash and proof, as well as the difficulty to check against. It returns a boolean of whether or not the Transaction is spam.

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
factor = (70 + (33 * amount of inputs) + (40 * amount of outputs)) / 143
spam(hash, proof, sendDifficulty * factor)
```

# Data Difficulty

The Data difficulty is initially set to 5 and is decided as described in the Consensus documentation.

In order for a Data's proof to beat the difficulty, the following check must pass:

```
factor = (101 + data.length) / 102
spam(hash, proof, dataDifficulty * factor)
```

# Gas Difficulty

The Gas difficulty is initially set to 8 and is decided as described in the Consensus documentation.

In order for a Unlock's proof to beat the difficulty, the following check must pass:

```
spam(hash, proof, gasDifficulty * usedGas)
```

# Blockchain Difficulty

The Blockchain difficulty is initially set to 10,000,000. When the fifth Block after the genesis is added, the difficulty starts updating every Block.

A window of Blocks is selected, including the newest Block. The window has a variable size depending on how long the Blockchain is.

- If the Blockchain height is less than 4320 (first month), the amount of Blocks used in the window is 5.
- If the Blockchain height is less than 12960 (first three months), the amount of Blocks used in the window is 9.
- If the Blockchain height is less than 25920 (first six months), the amount of Blocks used in the window is 18.
- If the Blockchain height is less than 52560 (first year), the amount of Blocks used in the window is 36.
- Else, the amount of Blocks used in the window is 72.

The first difficulty of the window is removed from consideration as the relevant work was mined before the timestamp indicates.

The `window.length / 10` Blocks with the most outlying difficulties from the median are removed from the window. When the window's length is even, the median is the higher difficulty. When both the lowest and the highest difficulties are as outlying as each other, the lower difficulty is removed.

The new difficulty is defined as `max(sum(windowDifficulties) * 600 / (window[window.length - 1].header.time - window[0].header.time), 1)`, where 600 represents the Block time.

### Violations in Meros:

- Meros uses an initial Blockchain difficulty of 10,000.
