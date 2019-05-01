# Header

A single byte header informing nodes of the type of message is prefixed before every message. This header is used to figure out the message length and how to handle the message.

The message types currently in Meros are as follows (with their list number being their byte header):
<ol start="0">
<li><code>Handshake</code></li>
<br>
<li><code>Syncing</code></li>
<li><code>SyncingAcknowledged</code></li>
<li><code>BlockRequest</code></li>
<li><code>VerificationRequest</code></li>
<li><code>EntryRequest</code></li>
<li><code>DataMissing</code></li>
<li><code>SyncingOver</code></li>
<br>
<li><code>Claim</code></li>
<li><code>Send</code></li>
<li><code>Receive</code></li>
<li><code>Data</code></li>
<li><code>MemoryVerification</code></li>
<li><code>Block</code></li>
<li><code>Verification</code></li>
</ol>

The other documentation will mention other message types, such as `MemoryVerificationRequest` and `MeritRemoval`. These are part of the protocol, yet not currently functional in Meros. They are not present in this list as they will affect the byte headers in currently undecided ways once added.
