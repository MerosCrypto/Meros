# Network Module

### `getPeers`
`getPeers` replies with a list of every node we're connected it. It takes in zero arguments and replies with an array of objects, each as follows:
- `ip`                                                              (string)
- `server`                                                          (bool)
- `port`: Only present we're connected to this peer's Server Socket (int)

### `connect`

`connect` attempts to connect to another Meros node. It takes in two arguments:
- IP/Domain                                   (string)
- Port: Optional, defaults to 5132 if omitted (int)

The result is a bool of true.

### `rebroadcast`

`rebroadcast` rebroadcasts existing local data. It takes in up to two arguments:
- ID 1: String of a Transaction hash/Merit Holder's BLS Public Key, or int of a Block number (string/int)
- ID 2: Element nonce; only used when ID 1 is a string of a Merit Holder's BLS Public Key    (int)

The result is a bool of true.
