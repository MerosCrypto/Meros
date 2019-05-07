# Lattice

The Lattice is a DAG made up of Accounts (balance + two dimensional Entry array), indexed by Ed25519 Public Keys, with an additional two properties of sendDifficulty and dataDifficulty (384 bit hashes set via methods described in the Verifications documentation). Only the key pair behind an Account can add an Entry to it.

Every Entry has the following fields:
- descendant: Entry Sub-type
- sender: Account that the Entry belongs to. The protocol defines this as the Ed25519 Public Key, but Meros uses addresses internally.
- nonce: Index of the Entry on the Account. Starts at zero and increments by one for every added Entry.
- hash: Blake2b-384 hash of the Entry; each sub-type hashes differently.
- signature: Signature of the hash signed by the sender.

The Entry sub-types are as follows:
- Mint
- Claim
- Send
- Receive
- Data
- Lock
- Unlock

When a new Entry is received via a `Claim`, `Send`, `Receive`, `Data`, `Lock`, or `Unlock` message, it should be added to the sender's Account, if long as the signature is correct and any other checks imposed by the sub-type pass. The reason why the array is two dimensional is in case two different Entries share the same sender/nonce. Until one is confirmed, as described in the Verifications documentation, both must remain on the Account.

### Mint

Mint Entries are locally created when blocks are added to the blockchain, as described in the Merit documentation, and never sent over the network. They also have the following fields:
- output: The BLS Public Key of the verifier who earned the new Meros.
- amount: The amount of Meri created.

Meros names the account Mints are added to "minter", yet the protocol is indifferent. Meros does not set the sender or signature fields of Mints, as there's no point. Meros does set the hash field, even though the hash is never broadcasted or needed to verify a signature, to allow looking up Mints. In order to maintain consistency across software, the protocol defines the hash as `Blake2b-384("mint" + nonce + output + amount)`, where nonce takes up four bytes, output 48 bytes, and amount eight bytes.

Mints are never broadcasted across the network, and should only be created by the local node.

### Claim

Claim Entries are created in response to a Mint, and have the following fields:
- mintNonce: The nonce of the Mint this is claiming.
- bls: BLS Signature that proves the verifier which earned the new Meros wants this Account to receive their reward.

Claim hashes are defined as `Blake2b-384("claim" + nonce + mintNonce + bls)`, where nonce takes up four bytes, mintNonce four bytes, and bls 96 bytes.

mintNonce must be lower than the height of the "minter" Account, and the Mint at that location must not have been previously claimed.

bls must be the BLS signature produced by the Private Key for the Mint's output signing `"claim" + mintNonce + sender`.

The sender's Account's balance, when combined with the amount from the Mint, must be lower than the max value of an uint64.

Once a Claim has been confirmed, the Mint's amount is added to the sender's Account's balance.

`Claim` has a message length of 200 bytes; the 32 byte sender, the four byte nonce, the four byte mintNonce, the 96 byte BLS signature, and the 64 byte Ed25519 signature.

### Send

Send Entries have the following fields:
- output: The Ed25519 Public Key to transfer funds to.
- amount The amount of Meri to send.
- proof: Work that proves this isn't spam.

Send hashes are defined as `Blake2b-384("send" + sender + nonce + output + amount)`, where sender takes up 32 bytes, nonce four bytes, output 32 bytes, and amount eight bytes.

amount must be less than or equal to the sender's Account's balance, after all Entries with a lower nonce are confirmed. The output's Account's balance, when combined with amount, must be lower than the max value of an uint64.

The proof must satisfy the following check:
```
Argon2d(
    iterations = 1,
    memory = 8,
    parallelism = 1
    data = hash,
    salt = proof with no leading zeros
) > sendDiffuclty
```

Once a Send has been confirmed, the amount is subtracted from the sender's Account's balance.

`Send` has a message length of 144 bytes; the 32 byte sender, the four byte nonce, the 32 byte output, the eight byte amount, the 64 byte Ed25519 signature, and the four byte proof.

### Receive

Receive Entries have the following fields:
- input: The Ed25519 Public Key who owns the Account which has the Send we're receiving.
- inputNonce: The nonce of the Send we're receiving.

Receive hashes are defined as `Blake2b-384("receive" + nonce + input + inputNonce)`, where nonce takes up four bytes, input 32 bytes, and inputNonce four bytes.

The Entry on input's Account at inputNonce must be a Send, with an output of sender, which doesn't have a matching receive yet.

The sender's Account's balance, when combined with the amount from the Send, must be lower than the max value of an uint64.

Once the Receive has been confirmed, the Send's amount is added to the sender's Account's balance.

`Receive` has a message length of 136 bytes; the 32 byte sender, the four byte nonce, the 32 byte input, the four byte mintNonce, and the 64 byte Ed25519 signature.

### Data

Data Entries have the following fields:
- data: The Data to store in the Entry.
- proof: Work that proves this isn't spam.

Data hashes are defined as `Blake2b-384("data" + sender + nonce + data.length + data)`, where sender takes up 32 bytes, nonce four bytes, data length one byte, and data variable bytes.

The proof must satisfy the following check:
```
Argon2d(
    iterations = 1,
    memory = 8,
    parallelism = 1
    data = hash,
    salt = proof with no leading zeros
) > dataDiffuclty
```

`Data` has a message length of 105 bytes, plus the variable length data; the 32 byte sender, the four byte nonce, the one byte data length, the variable byte data, the 64 byte Ed25519 signature, and the four byte proof.

### Lock

### Unlock

### Violations in Meros

- Meros doesn't support either `Lock` or `Unlock`.
