# Header

A header is 2+ bytes put before every message.

- The 1st byte is the content type.
- The 2nd byte is the message length.

If the message is longer than 255 bytes, the header will take up more than 2 bytes. The length will be serialized in the same way defined in `Serialization.md`.
