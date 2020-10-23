# BLS

Meros uses BLS12-381, following sections 1 and 2 (except 2.3) of the [BLS signature standard draft](https://tools.ietf.org/html/draft-irtf-cfrg-bls-signature-04), and fully following the [hash-to-curve draft](https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-10).

Meros uses the minimal signature size variant since public keys are nicknamed when they enter the system. Our signatures are closest to the proof of possession scheme defined in section 3 of the BLS signature standard, yet we do not require proofs to be bundled with every signature. Meros uses a single proof when a key enters the system, and this proof is not compliant with the specified proof algorithm.

The hash to curve algorithm uses a domain separation tag of "MEROS-V01-CS01-with-BLS12381G1_XMD:SHA-256_SSWU_RO_". This is not a valid ciphersuite tag according to the BLS signature standard, yet we already cannot form a valid tag due to not following any of the standards from section 3.

### Violations in Meros

- Meros's DST contains "V00" currently, as it has yet to launch.
