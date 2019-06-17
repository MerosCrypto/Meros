# Header

A 1-byte header is prefixed before every message to inform nodes of the type of message. Once a node knows the type of message, it can figure out the message length and how to handle the message.

The message types are as follows (with their list number being their byte header):

<ol start="0">
<li><code>Handshake</code></li>
<li><code>BlockHeight</code></li>
<br>
<li><code>Syncing</code></li>
<li><code>SyncingAcknowledged</code></li>
<li><code>PeerRequest</code></li>
<li><code>Peers</code></li>
<li><code>CheckpointRequest</code></li>
<li><code>BlockHeaderRequest</code></li>
<li><code>BlockBodyRequest</code></li>
<li><code>ElementRequest</code></li>
<li><code>TransactionRequest</code></li>
<li><code>GetBlockHash</code></li>
<li><code>BlockHash</code></li>
<li><code>GetVerifierHeight</code></li>
<li><code>VerifierHeight</code></li>
<li><code>SignedElementRequest</code></li>
<li><code>DataMissing</code></li>
<li><code>SyncingOver</code></li>
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
<li><code>Verification</code></li>
<li><code>SendDifficulty</code></li>
<li><code>DataDifficulty</code></li>
<li><code>GasPrice</code></li>
<li><code>MeritRemoval</code></li>
</ol>

`Syncing` is sent to set the state to Syncing, as described in the Syncing docs. Every message between `Syncing` (exclusive) and `SyncingOver` (inclusive) can only be sent when the state between two nodes is Syncing. The node which started syncing can only send some, and the node which didn't start syncing can only send others, as described in the Syncing documentation.

Even if the state is syncing, the node which didn't start syncing can send `BlockHeight`, along with every message between `Claim` (inclusive) and `Checkpoint` (inclusive).

When the state isn't syncing, nothing between `Syncing` (exclusive) and `SyncingOver` (inclusive), nor `BlockBody`, can be sent.
