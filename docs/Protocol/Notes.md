# Notes

- This documentation surrounds message types in `code brackets` and capitalizes DataTypes.

- All numbers are formatted as little-endian.
- A message length limit of 8 MiB is enforced.

- An Ed25519 public key which is zeroed out is treated as a valid public key, like any other 32-bytes of data. That said, no signature for a zeroed out public key is considered valid, despite it being possible to craft such a signature. This is because anyone can craft such a signature. While this is also true for other keys, a common assumption is a zero public key is invalid, and is therefore used to burn funds.
- Ed25519 Signatures are created with a prefix of "MEROS" before the signed data. This is to stop transaction replays across networks.
- If either IETF standards or Ethereum's specifications have finalized a BLS hashToG before Meros launches, Meros will likely switch over.

- 1 Meros is equivalent to 10,000,000,000 Meri, and Meri is the lowest denomination of Meros. This means Meros has 10 decimals.

- The Argon parameters used in the spam function will be changed before mainnet.
- `Locks`/`Unlocks` are not specified as the MerosScript specification is still under development.
- The negative sigmoid used for reward calculation is not specified as it is not finalized.

- All violations between the Meros codebase and the Meros protocol will be resolved before mainnet.
