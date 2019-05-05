# Lattice

The Lattice is a DAG made up of Accounts (balance + two dimensional Entry array), indexed by Ed25519 Public Keys. Only the key pair behind an Account can add an Entry to it.

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

Meros names the account Mints are added to "minter", yet the protocol is indifferent as Mints are never sent across the network. Meros does not set the sender or signature fields of Mints, as there's no point. Meros does set the hash field, even though the hash is never broadcasted or needed to verify a signature, to allow looking up Mints. In order to maintain consistency across software, the protocol defines the hash as `Blake2b-384("mint" + nonce + output + amount)`, where nonce takes up four bytes, output 48 bytes, and amount eight bytes.

### Claim

Claim Entries are created in response to a Mint, and have the following fields:
- mintNonce: The nonce of the Mint this is claiming.
- bls: BLS Signature that proves the verifier which earned the new Meros wants this Account to receive their reward.

mintNonce must be lower than the height of the "minter" Account, and the Mint at that location must not have been previously claimed.

bls must be the BLS signature produced by the Private Key for the Mint's output signing `"claim" + mintNonce + sender`.

Once a Claim has been confirmed, the Mint's amount should be added to the sender's Account's balance.

### Send

### Receive

### Data

### Lock

### Unlock

### Violations in Meros

- Meros doesn't support either `Lock` or `Unlock`.
