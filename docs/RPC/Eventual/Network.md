# Network Module

### `getPeers`
`getPeers` replies with a list of every node we're connected it. It takes in zero arguments and replies with an array of objects, each as follows:
- `ip`     (string)
- `server` (bool)
- `port`   (int): Only present if we're connected to this peer's Server Socket.

### `connect`

`connect` attempts to connect to another Meros node. It takes in two arguments:
- IP/Domain (string)
- Port      (int): Optional; defaults to 5132 if omitted.

The result is a bool of true.

### `rebroadcast`

`rebroadcast` rebroadcasts existing local data. It takes in up to two arguments:
- ID 1 (string/int): Transaction hash/Merit Holder's BLS Public Key as a string or Block nonce as an int.
- ID 2 (int):        Element nonce; only used when ID 1 is a string of a Merit Holder's BLS Public Key.

The result is a bool of true.
