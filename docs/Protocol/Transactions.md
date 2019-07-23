# Transactions

Transactions is a DAG made up of Transactions, each defining inputs and outputs, with an additional two properties of sendDifficulty and dataDifficulty (384 bit hashes set via methods described in the Consensus documentation).

Every Transaction has the following fields:

- descendant: Transaction sub-type.
- inputs: Array of `(txHash, txOutputIndex)` which feed this Transaction.
- outputs: Array of `(key, amount)` which were created by this Transaction.
- hash: Blake2b-384 hash of the Transaction; each sub-type hashes differently.

The Transaction sub-types are as follows:

- Mint
- Claim
- Send
- Data
- Lock
- Unlock

When a new Transaction is received via a `Claim`, `Send`, `Data`, `Lock`, or `Unlock` message, it's added to the Transactions DAG, as long as it has at least one input and the checks imposed by the sub-type pass.

### Mint

Mint Transactions are locally created when Blocks are added to the Blockchain, as described in the Merit documentation, and are never sent over the network. They have the following additional field:

- nonce: The nonce for this Mint. The first has a nonce of 0, the second has a nonce of 1...

Mints have no inputs, yet are considered to be created by "minter". It has a single output, whose key is a BLS Public Key and whose amount is the amount being minted.

The hash is defined as `Blake2b-384("\0" + nonce + output.key + output.amount)`, where nonce takes up 4 bytes, the output key 48 bytes, and the output amount 8 bytes.

### Claim

Claim Transactions are created in response to a Mint, and have the following additional field:

- signature: BLS Signature that proves the Merit Holder which earned the newly minted Meros wants this person to receive their reward.

Claim inputs are hashes of Mints which have yet to be claimed. As Mints have a singular output, the input index is not used. The Claim's singular output is to an Ed25519 Public Key with the amount being the sum of the Mint amounts. The specified key does not need to be a valid Ed25519 Public Key.

signature must be the BLS signature produced by Mint's designated claimee signing `"\1" + mint.hash + claim.output.key`, where mint.hash takes up 48 bytes and claim.output.key takes up 32 bytes, for every input, and then aggregating the produced signatures (if there's more than one). If the Mints are for different BLS Public Keys, the designated claimee is the aggregated BLS Public Key created from every unique BLS Public Key.

Claim hashes are defined as `Blake2b-384("\1" + signature)`, where signature takes up 96 bytes.

`Claim` has a variable message length; the 1-byte amount of inputs, the inputs (each 48 bytes), the 32-byte output key, and the 96-byte BLS signature.

### Send

Send Transactions have the following additional field:

- signature: Ed25519 Signature.
- proof: Work that proves this isn't spam.

Every Send must have at least 1 input. Every Send input must be either a Claim or a Send, where the specified output is to the sender. If the specified outputs are to different keys, the sender is the MuSig Public Key created out of the unique keys. No transaction outputs specified as inputs must have been used as inputs before.

Every output's key must be an Ed25519 Public Key. The specified key does not need to be a valid Ed25519 Public Key. The output's amount must be non-zero.

The amount sent in the transaction must be less than (2 ^ 64) - 1. The sum of the amount of every output must be equal to the sum of the amount of every input.

Send hashes are defined as `Blake2b-384("\2" + inputs[0] + ... + inputs[n] + outputs[0] + ... outputs[n])`, where every input takes up 49 bytes (the 48-byte hash and 1-byte output index) and every output takes up 40 bytes (the 32-byte key and 8-byte amount).

The signature must be the signature produced by the sender signing the hash.

The proof must satisfy the following check, where sendDifficulty is the Sends' spam filter's difficulty (described in the Consensus documentation):

```
Argon2d(
    iterations = 1,
    memory = 8,
    parallelism = 1
    data = hash,
    salt = proof left padded to be 8 bytes long
) > sendDifficulty
```

`Send` has a variable message length; the 1-byte amount of inputs, the inputs (each 49 bytes), 1-byte amount of outputs, the outputs (each 40 bytes), the 64-byte Ed25519 signature, and the 4-byte proof.

### Data

Data Transactions have the following fields:

- data: The Data to store in the Transaction.
- signature: Ed25519 Signature.
- proof: Work that proves this isn't spam.

Data Transactions are sequential. The first Data Transaction a sender creates has a single input of their Ed25519 Public Key, left-padded with 16 zeroed out bytes. From then on, Data Transactions always have a single input; the Argon hash (see below) of the previous Data Transaction created by that sender. Data Transactions' input's index and outputs are not used.

Data hashes are defined as `Blake2b-384("\3" + input.txHash + data)`, where input.txHash takes up 48 bytes and data variable bytes.

The signature must be the signature produced by the sender signing the hash.

The data must be less than 256 bytes long (enforced by only providing a single byte to store the data length).

The proof must satisfy the following check, where dataDifficulty is the Datas' spam filter's difficulty (described in the Consensus documentation):

```
Argon2d(
    iterations = 1,
    memory = 8,
    parallelism = 1
    data = hash,
    salt = proof left padded to be 8 bytes long
) > dataDifficulty
```

The produced Argon hash must also not start with 16 0s.

`Data` has a variable message length; the 48-byte input, the 1-byte data length, the variable-byte data, the 64-byte Ed25519 signature, and the 4-byte proof.

### Lock

### Unlock

### Violations in Meros

- Meros uses Data hashes, instead of Data Argon hashes, for inputs.
- Meros doesn't check if Datas's Argon hashes start with 0s or not.
- Meros doesn't support Lock or Unlock Transactions.
