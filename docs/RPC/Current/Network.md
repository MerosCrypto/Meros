# Network Module

### `connect`

`connect` attempts to connect to another Meros node. It takes in two arguments:
- IP/Domain (string)
- Port      (int): Optional; defaults to 5132 if omitted.

The result is a bool of true.

### `getPeers`
`getPeers` replies with a list of every node we're connected it. It takes in zero arguments and replies with an array of objects, each as follows:
- `ip`     (string)
- `server` (bool)
- `port`   (int): Only present the peer has a Server Socket.
