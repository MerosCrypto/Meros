# Header

A header is 4+ bytes put before every message.

- The 1st byte is the network ID.
- The 2nd byte is the protocol version.
- The 3rd byte is the content type.
- The 4th byte is the message length.

If the message is longer than 255 bytes, the header will take up more than 4 bytes. The length will be serialized in the same way defined in `Serialization.md`.
