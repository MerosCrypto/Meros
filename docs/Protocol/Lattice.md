# Lattice

The Lattice is a DAG made up of Accounts (balance + two dimensional Entry array) indexed by Ed25519 Public Keys, with an additional two properties of sendDifficulty and dataDifficulty (384 bit hashes set via methods described in the Consensus documentation). Only the key pair behind an Account can add an Entry to it.

Every Entry has the following fields:

- descendant: Entry Sub-type
- sender: Account that the Entry belongs to. The protocol defines this as the Ed25519 Public Key, but Meros uses addresses internally.
- nonce: Index of the Entry on the Account. Starts at 0 and increments by 1 for every added Entry.
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

When a new Entry is received via a `Claim`, `Send`, `Receive`, `Data`, `Lock`, or `Unlock` message, it's be added to the sender's Account, as long as the signature (produced by the sender signing the hash) is correct and any other checks imposed by the sub-type pass. The reason why the array is two dimensional is in case two different Entries share the same sender/nonce. Until one is verified, as described in the Consensus documentation, both must remain on the Account.

### Mint

Mint Entries are locally created when Blocks are added to the Blockchain, as described in the Merit documentation, and never sent over the network. They also have the following fields:

- output: The BLS Public Key of the verifier who earned the new Meros.
- amount: The amount of Meri created.

Every Mint has a sender of "minter", yet the signature is left blank as there's no way to produce a valid signature. The hash is defined as `Blake2b-384("mint" + nonce + output + amount)`, where nonce takes up 4 bytes, output 48 bytes, and amount 8 bytes.

Mints are never broadcast across the network and are only be created by the local node.

### Claim

Claim Entries are created in response to a Mint, and have the following fields:

- mintNonce: The nonce of the Mint that is being claimed.
- bls: BLS Signature that proves the Merit Holder which earned the newly minted Meros wants this Account to receive their reward.

Claim hashes are defined as `Blake2b-384("claim" + nonce + mintNonce + bls)`, where nonce takes up 4 bytes, mintNonce 4 bytes, and bls 96 bytes.

mintNonce must be lower than the height of the "minter" Account, and the Mint at that location must not have been previously claimed.

bls must be the BLS signature produced by the Private Key for the Mint's output signing `"claim" + mintNonce + sender`.

The sender's Account's balance, when combined with the amount from the Mint, must be lower than the max value of an uint64.

Once a Claim has been verified, the Mint's amount is added to the sender's Account's balance.

`Claim` has a message length of 200 bytes; the 32-byte sender, the 4-byte nonce, the 4-byte mintNonce, the 96-byte BLS signature, and the 64-byte Ed25519 signature.

### Send

Send Entries have the following fields:

- output: The Ed25519 Public Key to allow to receive these funds. This doesn't need to be a valid Public Key.
- amount The amount of Meri to send.
- proof: Work that proves this isn't spam.

Send hashes are defined as `Blake2b-384("send" + sender + nonce + output + amount)`, where sender takes up 32 bytes, nonce 4 bytes, output 32 bytes, and amount 8 bytes.

amount must be less than or equal to the sender's Account's balance, after all Entries with a lower nonce are verified. The output's Account's balance, when combined with amount, must be lower than the max value of an uint64.

The proof must satisfy the following check, where sendDifficulty is the Sends' spam filter's difficulty (described in the Consensus documentation):

```
Argon2d(
    iterations = 1,
    memory = 8,
    parallelism = 1
    data = hash,
    salt = proof with no leading 0s
) > sendDifficulty
```

Once a Send has been verified, the amount is subtracted from the sender's Account's balance.

`Send` has a message length of 144 bytes; the 32-byte sender, the 4-byte nonce, the 32-byte output, the 8-byte amount, the 64-byte Ed25519 signature, and the 4-byte proof.

### Receive

Receive Entries have the following fields:

- input: The Ed25519 Public Key who owns the Account which has the Send we're receiving.
- inputNonce: The nonce of the Send we're receiving.

Receive hashes are defined as `Blake2b-384("receive" + nonce + input + inputNonce)`, where nonce takes up 4 bytes, input 32 bytes, and inputNonce 4 bytes.

The Entry on input's Account at inputNonce must be a verified Send, with an output of sender, which doesn't have a matching receive yet.

The sender's Account's balance, when combined with the amount from the Send, must be lower than the max value of an uint64.

Once the Receive has been verified, the Send's amount is added to the sender's Account's balance.

`Receive` has a message length of 136 bytes; the 32-byte sender, the 4-byte nonce, the 32-byte input, the 4-byte mintNonce, and the 64-byte Ed25519 signature.

### Data

Data Entries have the following fields:

- data: The Data to store in the Entry.
- proof: Work that proves this isn't spam.

Data hashes are defined as `Blake2b-384("data" + sender + nonce + data.length + data)`, where sender takes up 32 bytes, nonce 4 bytes, data length 1 byte, and data variable bytes.

The data must be less than 256 bytes long (enforced by only providing a single byte to store the data length).

The proof must satisfy the following check, where dataDifficulty is the Datas' spam filter's difficulty (described in the Consensus documentation):

```
Argon2d(
    iterations = 1,
    memory = 8,
    parallelism = 1
    data = hash,
    salt = proof with no leading 0s
) > dataDifficulty
```

`Data` has a message length of 105 bytes, plus the variable length data; the 32-byte sender, the 4-byte nonce, the 1-byte data length, the variable-byte data, the 64-byte Ed25519 signature, and the 4-byte proof.

### Lock

### Unlock

### Violations in Meros

- Meros doesn't support either `Lock` or `Unlock`.
