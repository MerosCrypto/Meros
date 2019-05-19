# Notes

- This documentation surrounds message types in `code brackets` and capitalizes DataTypes.
- All data is serialized as big endian.
- 1 Meros is equivalent to 10,000,000,000 Meri, and Meri is the lowest denomination of Meros. This means Meros has 10 decimals.
- Ed25519 Signatures are created with a prefix of "MEROS" before the signed data. This is to stop transaction replays across networks.
- The used BLS specification is BLS12-381. Meros currently uses Chia's BLS library, yet Meros will move to either Herumi or Milagro before mainnet.
- `Locks`/`Unlocks` are not specified as the MerosScript specification is still under development.
- The specified Argon parameters are not final, nor is the usage of Argon itself. Block mining will definitely use a different algorithm, likely RandomX wrapped in AES.
- The Difficulty algorithm is not specified as it will be changed before mainnet.
- The negative sigmoid used for reward calculation is not specified as it is not finalized.
- All violations between the Meros codebase and the Meros protocol will be resolved before mainnet.
