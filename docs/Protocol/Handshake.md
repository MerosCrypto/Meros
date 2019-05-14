# Handshake

`Handshake` is a dual purpose message. sent when two nodes first connect and as a keep-alive message which returns the other node's Blockchain's height. It has a message length of six bytes, with the first byte being the network ID, the second byte being the protocol ID, and the next four bytes being the local Blockchain height.

### Violations in Meros

- Meros only supports handshaking on connection, not as a keep alive message.
