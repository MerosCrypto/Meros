# Header

A single byte header informing nodes of the type of message is prefixed before every message. This header is used to figure out the message length and how to handle the message.

The message types are as follows (with their list number being their byte header):

<ol start="0">
<li><code>Handshake</code></li>
<br>
<li><code>Syncing</code></li>
<li><code>SyncingAcknowledged</code></li>
<li><code>BlockRequest</code></li>
<li><code>ElementRequest</code></li>
<li><code>EntryRequest</code></li>
<li><code>GetAccountHeight</code></li>
<li><code>AccountHeight</code></li>
<li><code>GetHashesAtIndex</code></li>
<li><code>HashesAtIndex</code></li>
<li><code>GetVerifierHeight</code></li>
<li><code>VerifierHeight</code></li>
<li><code>SignedElementRequest</code></li>
<li><code>DataMissing</code></li>
<li><code>SyncingOver</code></li>
<br>
<li><code>Claim</code></li>
<li><code>Send</code></li>
<li><code>Receive</code></li>
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
<li><code>Block</code></li>
<li><code>Verification</code></li>
<li><code>SendDifficulty</code></li>
<li><code>DataDifficulty</code></li>
<li><code>GasPrice</code></li>
<li><code>MeritRemoval</code></li>
</ol>

`Syncing` is sent to set the state to Syncing, as described in the Syncing docs. Every message between `Syncing` (exclusive) and `SyncingOver` (inclusive), can only be sent when the state between two nodes is Syncing. The node which started syncing can only send some, and the node which didn't start syncing can only send others, as described in the Syncing docs.

Even if the state is syncing, the node which didn't start syncing can send every message between `Claim` (inclusive) and `MeritRemoval` (inclusive).

When the state isn't syncing, only `Handshake`, `Syncing`, and everything after `SyncingOver` (exclusive) can be sent,

### Violations in Meros:

- Meros doesn't support several message types, as specified in the other documentation. Meros generates an enum without said message types, which causes different header bytes to be used.
