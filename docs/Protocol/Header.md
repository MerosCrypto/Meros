# Header

A 1-byte header is prefixed before every message to inform nodes of the type of message. Once a node knows the type of message, it can figure out the message length and how to handle the message.

The message types are as follows (with their list number being their byte header):

<ol start="0">
<li><code>Handshake</code></li>
<li><code>Syncing</code></li>
<li><code>BlockchainTail</code></li>
<br>
<li><code>PeersRequest</code></li>
<li><code>Peers</code></li>
<li><code>BlockListRequest</code></li>
<li><code>BlockList</code></li>
<br>
<li><code>CheckpointRequest</code></li>
<li><code>BlockHeaderRequest</code></li>
<li><code>BlockBodyRequest</code></li>
<li><code>SketchHashesRequest</code></li>
<li><code>SketchHashRequests</code></li>
<li><code>TransactionRequest</code></li>
<li><code>DataMissing</code></li>
<br>
<li><code>Claim</code></li>
<li><code>Send</code></li>
<li><code>Data</code></li>
<li><code>Lock</code></li>
<li><code>Unlock</code></li>
<br>
<li><code>SignedVerification</code></li>
<li><code>SignedSendDifficulty</code></li>
<li><code>SignedDataDifficulty</code></li>
<li><code>SignedGasPrice</code></li>
<li><code>SignedMeritRemoval</code></li>
<br>
<li><code>Checkpoint</code></li>
<li><code>BlockHeader</code></li>
<li><code>BlockBody</code></li>
<li><code>SketchHashes</code></li>
<li><code>VerificationPacket</code></li>
</ol>

Every message between `Syncing` and `DataMissing`, as well as everything after `BlockBody` (inclusive), can only be sent over the Sync socket. `Handshake`, as well as every message between `SignedVerification` and `SignedMeritRemoval` can only be sent over the Live socket. Every other message (`BlockchainTail`, `Claim` through `Unlock`, `Checkpoint`, and `BlockHeader`) can be sent over either socket.

The Live socket is a connection where every message is proactive. When a node rebroadcasts new data, it's sent over the Live Socket. The Sync socket is a connection where every message is reactive. One party makes a request and one party makes a response. Either party can make a request at any point in time, yet the responses must be in the exact same order as the requests.

Both sockets share the same port. This causes every node to have between 1 and 2 connections with each peer. Whoever causes the connection sends the first message, a procedure described in the Handshake documentation. Determining if a connection is the Sync socket or the Live socket is done via this first message.
