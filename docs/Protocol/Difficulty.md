# Difficulty

The difficulty algorithm used in the Blockchain is heavily inspired from Cryptonote. Difficulty is represented as an unsigned 64-bit integer where `difficulty / 2 + 1` is the average amount of hashes needed to create a valid BlockHeader. The difficulty is initially set to 10,000,000. When the third Block after the genesis is added, the difficulty starts updating every Block.

A window of Blocks is selected, including the newest Block. The window has a variable size depending on how long the Blockchain is.

- If the Blockchain height is less than 1008 (first week), the amount of Blocks used in the window is 3.
- If the Blockchain height is less than 4320 (first month), the amount of Blocks used in the window is 18.
- If the Blockchain height is less than 12960 (first three months), the amount of Blocks used in the window is 36.
- If the Blockchain height is less than 25920 (first six months), the amount of Blocks used in the window is 72.
- If the Blockchain height is less than 52560 (first year), the amount of Blocks used in the window is 144.

The `window.length / 10` Blocks with the most outlying difficulties from the median are removed from the window.

The new difficulty is defined as `sum(windowDifficulties) * 600 / (window[window.length - 1].header.time - window[1].header.time)`.

### Violations in Meros

- Meros uses a 256-bit difficulty, not a 64-bit difficulty.
- Meros has a different initial difficulty.
- Meros uses a different amount of Blocks depending on how long the Blockchain is.
- Meros doesn't remove outlying difficulties.
- Meros uses a different formula to calculate the next difficulty.
