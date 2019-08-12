# Handshake

`Handshake` is a dual purpose message, sent when two nodes first connect and as a keep-alive message which returns the other node's Blockchain's height. It has a message length of 7 bytes; the 1-byte network ID, 1-byte protocol ID, 1-byte of 255, if the sender is accepting clients, or 0 if they aren't, and 4-byte sender's Blockchain's height. Both nodes send it on connection. If a node sends it after connection, the expected response is a `BlockHeight`.

# BlockHeight

`BlockHeight` is the expected response to a `Handshake` sent after clients have already performed their initial connection. It has a message length of 4 bytes; the 4-byte sender's Blockchain's height (including the Genesis block).
