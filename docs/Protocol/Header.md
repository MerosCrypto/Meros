# Header

A single byte header informing Nodes of the type of message is prefixed before every message. This header is used to figure out the message length and how to handle the message.

The valid Message Types are as follows (with their list number being their byte):
<ol start="0">
<li>Handshake</li>
<br>
<li>Syncing</li>
<li>SyncingAcknowledged</li>
<li>BlockRequest</li>
<li>VerificationRequest</li>
<li>EntryRequest</li>
<li>DataMissing</li>
<li>SyncingOver</li>
<br>
<li>Claim</li>
<li>Send </li>
<li>Receive</li>
<li>Data</li>
<li>MemoryVerification</li>
<li>Block</li>
<li>Verification</li>
</ol>
