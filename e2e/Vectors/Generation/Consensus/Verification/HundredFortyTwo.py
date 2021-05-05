import json

import e2e.Libs.Ristretto.ed25519 as ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

transactions: Transactions = Transactions()
spamFilter: SpamFilter = SpamFilter(5)

proto = PrototypeChain(1, False)
proto.add(1)

data: Data = Data(bytes(32), edPubKey)
data.sign(edPrivKey)
data.beat(spamFilter)
transactions.add(data)

verif: SignedVerification = SignedVerification(data.hash)
verif.sign(1, PrivateKey(1))

proto.add(1, packets=[VerificationPacket(data.hash, [0])])
for _ in range(5):
  proto.add(1)

with open("e2e/Vectors/Consensus/Verification/HundredFortyTwo.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "transactions": transactions.toJSON(),
    "verification": verif.toSignedJSON(),
    "transaction": data.hash.hex().upper()
  }))
