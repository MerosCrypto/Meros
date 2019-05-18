# Handshake

`Handshake` is a dual purpose message, sent when two nodes first connect and as a keep-alive message which returns the other node's Blockchain's height. It has a message length of 7 bytes; the 1-byte network ID, 1-byte protocol ID, 1-byte of 255, if the sender is accepting clients, or 0 if they aren't, and 4-byte sender's Blockchain's height. The expected response is a `Handshake`.

### Violations in Meros

- Meros only supports handshaking on connection, not as a keep alive message.
