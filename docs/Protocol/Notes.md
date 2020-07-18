# Notes

- This documentation surrounds message types in `code brackets` and capitalizes DataTypes.

- All numbers are formatted as little-endian.
- A message length limit of 8 MiB is enforced.

- Ed25519 Signatures are created with a prefix of "MEROS" before the signed data. This is to stop transaction replays across networks.
- If either IETF standards or Ethereum's specifications have finalized a BLS hashToG before Meros launches, Meros will likely switch over.

- 1 Meros is equivalent to 10,000,000,000 Meri, and Meri is the lowest denomination of Meros. This means Meros has 10 decimals.

- The Argon parameters used in the spam function will be changed before mainnet.
- `Locks`/`Unlocks` are not specified as the MerosScript specification is still under development.
- The negative sigmoid used for reward calculation is not specified as it is not finalized.

- All violations between the Meros codebase and the Meros protocol will be resolved before mainnet.
