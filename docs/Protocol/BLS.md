# BLS

Meros uses BLS12-381, with G1 for Signatures and G2 for Public Keys. These are always compressed and therefore 48 and 96 bytes, respectively.

### G1 Serialization

A serialized G1 is composed of `C_FLAG`, `B_FLAG`, `A_FLAG`, and `X`. The flags take up the most significant bits of the the first byte and `X` takes up the other 381 bits.

- `C_FLAG` is 1 if the G1 is compressed. As Meros always uses compressed elements, this flag must always be set.
- `B_FLAG` is 1 if the G1 is infinite. If this flag is set, `A_FLAG` and `X` must be 0. If this flag is not set, `X` must not be 0.
- `A_FLAG` is 1 if the larger Y of the two possible Ys for this X is used.

### G2 Serialization

A serialized G2 is composed of two 48-byte segments, referred to as Z1 and Z2. Z1 is composed of `C1_FLAG`, `B1_FLAG`, `A1_FLAG`, and `X1`. Z2 is composed of `C2_FLAG`, `B2_FLAG`, `A2_FLAG`, and `X2`.

- `C1_FLAG` is 1 if the G2 is compressed. As Meros always uses compressed elements, this flag must always be set.
- `B1_FLAG` is 1 if the G2 is infinite. If this flag is set, `A1_FLAG`, `X1`, and `X2` must be 0. If this flag is not set, `X1` or `X2` must not be 0.
- `A1_FLAG` is 1 if the larger Y of the two possible Ys for this X is used.
- `C2_FLAG`, `B2_FLAG`, and `A2_FLAG` must be 0.

### Hash To G1

Messages are converted to a hash via using SHAKE256 to produce a 48-byte value. Then, the hash is converted to a G1 via [Milagro's map function](https://github.com/apache/incubator-milagro-crypto-c/blob/develop/src/ecp.c.in#L365).
