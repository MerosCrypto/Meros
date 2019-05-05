# Lattice

The Lattice is a DAG made up of Accounts (balance + two dimensional Entry array), indexed by Ed25519 Public Keys. Only the key pair behind an Account can add an Entry to it.

Every Entry has the following fields:
- `descendant`: Entry Sub-type
- `sender`: Account that the Entry belongs to. The protocol defines this as the Ed25519 Public Key, but Meros uses addresses internally.
- `nonce`: Index of the Entry on the Account. Starts at zero and increments by one for every added Entry.
- `hash`: Blake2b-384 hash of the Entry; each sub-type hashes differently.
- `signature`: Signature of the hash signed by the sender.

The Entry sub-types are as follows:
- Mint
- Claim
- Send
- Receive
- Data
- Lock
- Unlock

When a new Entry is received via a `Claim`, `Send`, `Receive`, `Data`, `Lock`, or `Unlock`, it should be added to the sender's Account, as long as the signature is correct. The reason why the array is two dimensional is in case two different Entries share the same sender/nonce. Until one is confirmed, as described in the Verifications documentation, both must remain on the Account.

### Mint

Mint entries are locally created when blocks are added to the blockchain, as described in the Merit documentation, and never sent over the network. They also have the following fields:
- `output`: The BLS Public Key of the miner who earned the new Meros.
- `amount`: The amount of Meros created.

Meros names the account Mints are added to "minter", yet the protocol is indifferent as Mints are never sent across the network. Meros does not set the `sender` or `signature` fields of Mints, as there's no point. Meros does set the `hash` field, even though the hash is never broadcasted or needed to verify a signature, to allow looking up Mints. In order to maintain consistency across software, the protocol defines the hash as `Blake2b-384("mint" + nonce + output + amount)`, where nonce takes up four bytes, output 48 bytes, and amount eight bytes.

### Claim

### Send

### Receive

### Data

### Lock

### Unlock

### Violations in Meros

- Meros doesn't support either `Lock` or `Unlock`.
