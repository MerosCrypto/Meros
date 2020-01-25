# Handshake

`Handshake` is sent when two nodes form a new connection. It declares the current connection as the Live socket. It has a message length of 5-bytes; the 1-byte network ID, 1-byte protocol ID, 1-byte supported services, and 2-byte server port.

The supported services byte uses bit masks to declare support for various functionality.

- 0b10000000 declares that the node is accepting connections via a server socket.

Every other bit is currently unused.

If a node sends it after connection, the expected response is a `BlockchainTail`.

# Syncing

`Syncing` is sent when two nodes form a new connection. It declares the current connection as the Sync socket. It has a message length of 37-bytes; the 1-byte network ID, 1-byte protocol ID, 1-byte supported services, 2-byte server port, and the 32-byte sender's Blockchain's tail Block's hash.

The supported services byte uses bit masks to declare support for various functionality.

- 0b10000000 declares that the node is accepting connections via a server socket.

Every other bit is currently unused.

If a node sends it after connection, the expected response is a `BlockchainTail`.

# BlockchainTail

`BlockchainTail` is the expected response to a `Syncing` sent after the peers have already performed their initial connection. It has a message length of 32 bytes; the 32-byte sender's Blockchain's tail Block's hash.
