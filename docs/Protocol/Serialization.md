# Serialization

All data is transmitted as raw binary. To separate between arguments, which aren't guaranteed to be of a certain length, each argument is prefixed with its length. If the argument is over 255 bytes, the prefix will use multiple bytes, signaled by the byte being `FF`. If the byte count is evenly divisible by 255, the last byte in the prefix will be `00`.

- A 3 byte piece of data has the prefix `03`.
- A 500 byte piece of data has the prefix `FFF5`.
- A 511 byte piece of data has the prefix `FFFF01`.
- A 255 byte piece of data has the prefix `FF00`.
