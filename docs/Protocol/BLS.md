# BLS

Meros uses BLS12-381, with G1 for Signatures and G2 for Public Keys, along with ZCash's serialization standard (which Ethereum has adopted for Eth 2.0). Signatures and Public Keys are always compressed and therefore 48 and 96 bytes, respectively.

### Hash To G1

Messages are converted to a hash via using SHAKE256 to produce a 48-byte value. Then, the hash is converted to a G1 via [Milagro's map function](https://github.com/apache/incubator-milagro-crypto-c/blob/develop/src/ecp.c.in#L365).
