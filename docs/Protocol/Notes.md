# Notes

- 1 Meros is equivalent to 10,000,000,000 Meri, and Meri is the lowest denomination of Meros. This means Meros has 10 decimals.
- The used BLS specification is BLS12-381. Meros currently uses Chia's BLS library, yet will move to either Herumi or Milagro.
- Ed25519 Signatures are created with a prefix of "MEROS" before the signed data. This is to stop transaction replays across networks.
- The specified Argon parameters are not final, nor is the usage of Argon itself. Block mining will definitely use a different algorithm, likely RandomX wrapped in AES.
- The Difficulty algorithm is not specified as it will be changed before mainnet,
- This documentation surrounds message types in `code brackets`, and capitalizes DataTypes.
- All data is serialized as big endian.
