# Handshake

`Handshake` is a dual purpose message, sent when two nodes first connect and as a keep-alive message which returns the other node's Blockchain's tail Block's hash. It has a message length of 35 bytes; the 1-byte network ID, 1-byte protocol ID, 1-byte of 1, if the sender is accepting clients or 0 if they aren't, and 32-byte sender's Blockchain's tail Block's hash. Both nodes send it on connection. If a node sends it after connection, the expected response is a `BlockchainTail`.

# BlockchainTail

`BlockchainTail` is the expected response to a `Handshake` sent after clients have already performed their initial connection. It has a message length of 32 bytes; the 32-byte sender's Blockchain's tail Block's hash.
