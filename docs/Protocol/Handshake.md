# Services

The services byte(s) is a VarInt with a maximum serialized length of 4 bytes (28 bits). Bit masks are used to declare support for various functionality.

- The lowest bit declares that the node is accepting connections via a server socket.

Every other bit is currently unused.

# Handshake

`Handshake` is sent when two nodes form a new connection. It declares the current connection as the Live socket. It has a variable message length; a VarInt for the protocol ID, a VarInt for the network ID, a VarInt for the services, 2-byte server port, and the 32-byte sender's Blockchain's tail Block's hash.

If a node sends it after connection, the expected response is a `BlockchainTail`.

# Syncing

`Syncing` is sent when two nodes form a new connection. It declares the current connection as the Sync socket. It has a variable message length; a VarInt for the protocol ID, a VarInt for the network ID, a VarInt for the services, 2-byte server port, and the 32-byte sender's Blockchain's tail Block's hash.

# Busy

`Busy` is sent when a node receives a connection, which it can accept, yet is unwilling to handle it due to the lack of some resource. It's a valid response to either handshake message, yet only to the initial handshake. Beyond the message byte, it is a clone of `Peers` (described in the Syncing documentation), enabling nodes who tried to connect, and failed, to learn of other nodes to try.

# BlockchainTail

`BlockchainTail` is the expected response to a `Handshake` or `Syncing` which was sent after the peers have already performed their initial handshake. It has a message length of 32 bytes; the 32-byte sender's Blockchain's tail Block's hash.
