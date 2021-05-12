# Notes

- This documentation surrounds message types in `code brackets` and capitalizes DataTypes.

- All numbers are formatted as little-endian.

- A message length limit of 8 MiB is enforced.

- Ristretto is used with EdDSA; specifically PureEdDSA with Blake2b-512 as the hash function.

- EdDSA Signatures are created with a prefix of "MEROS" before the message. This is to stop transaction replays across networks.

- A Ristretto Public Key which is zeroed out is treated as a valid Public Key, like any other 32-bytes of data. That said, no signature for a zeroed out Public Key is considered valid, despite it being possible to craft such a signature. This is because anyone can craft such a signature, yet a common assumption is that a zero Public Key is invalid. This creates a definitive and dedicated burn address.

- 1 Meros is equivalent to 10,000,000,000 Meri, and Meri is the lowest denomination of Meros. This means Meros has 10 decimals.

- The Argon parameters used in the spam function will be changed before mainnet.

- The negative sigmoid used for reward calculation is not specified as it is not finalized.

- All violations between the Meros codebase and the Meros protocol will be resolved before mainnet.
