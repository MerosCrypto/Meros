# Merit

Merit is a blockchain used to:

- Archive the Consensus DAG, providing a complete overview.
- Distribute Merit.
- Mint new Meros.

BlockHeaders have the following fields:

- nonce: Nonce of the Block,
- last: Last Block Hash.
- aggregate: Aggregated BLSSignature of every Element this Block archives.
- miners: Merkle tree hash of the Miners who earned this Block's Merit.
- time: Time this Block was mined at.
- proof: Arbitrary data used to beat the difficulty.

`BlockHeader` has a message length of 208 bytes; the 4 byte nonce, the 48 byte last hash, the 96 byte aggregate signature, the 48 byte miners Merkle tree hash, the 8 byte time, and the 4 byte proof.

Blocks have the following fields:

- header: Block's BlockHeader.
- records: List of MeritHolders (BLS Public Keys), Nonces, and Merkle tree hashes.
- miners: List of Miners (BLS Public Keys) and Merit amounts to payout.

When a new Block is received, it should be tested for validity. A Meros MainNet Blockchain is valid if:

- The genesis block has a:
	-  Nonce of 0
	-  Last hash of "MEROS_MAINNET", left padded with 0s until it has a length of 48 bytes.
	-  0'd out aggregate field.
	-  0'd out miners field.
	-  Time of 0.
	-  Proof of 0.
	-  Empty list of records,
	-  Empty list of miners,
- BlockHeader nonces always increment by one as the blockchain progresses.
- The last field of each BlockHeader is  the hash ofd the previous Block.
- No Block has multiple records for a single key.
- No Block has a record with a nonce lower than the previous record for that key.
- No BlockHeader has a record with an invalid Merkle tree hash (as described in the Consensus documentation).
- Every BlockHeader for a Block with no records has a 0'd out aggregate signature.
- Every BlockHeader for a Block with records has an aggregate signature created by the following algorithm:

```
List[BLSSignature] verifierSignatures
for r in records:
	List[BLSSignature] elementSignatures
	for n in previousRecordNonce[r.key] + 1 .. r.nonce:
    	signedElement = consenus[r.key][n]
        elementSignatures.add(signedElement.signature)

    verifierSignatures.add(elementSignatures.aggregate())
    previousRecordNonce[r.key] = r.nonce

BLSSignature aggregate = verifierSignatures.aggregate()
```

- No Block has a miner with an invalid key and the total of every miner in that Block's amount equals 100.
- No Block has a miner with an amount less than 1.
- Every BlockHeader's miners Merkle tree hash is accurate.
- Every BlockHeader's time is greater than the previous BlockHeader's time.
- Every BlockHeader's time is less than 20 minutes in the futures.
- Every BlockHeader's hash beat their Difficulty.

### BlockHeader

`BlockHeader` has a message length of 208 bytes; the 4 byte nonce, the 48 byte last hash, the 96 byte aggregate signature, the 48 byte miners Merkle tree hash, the 8 byte time, and the 4 byte proof.

### Block

`Block` has a variable message length; the 208 byte BlockHeader (serialized as described above), the 4 byte amount of records, the records (each with a 48 byte BLS Public Key, 4 byte nonce, and 48 byte Merkle tree hash), the 1 byte amount of miners, and the miners (each with a 48 byte BLS Public Key and 1 byte amount).

### Violations in Meros

- Meros doesn't support the `BlockHeader` message type.
