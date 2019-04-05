# Serialization

All data is transmitted as raw binary. Most segments are fixed length, yet the few variable length segments (Data's `data` and Block's `VerifierIndex`s/`Miners`) we have are prefixed by either a single byte or four bytes representing the argument length.
