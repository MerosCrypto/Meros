from typing import IO, Any
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

transactions: Transactions = Transactions()
spamFilter: SpamFilter = SpamFilter(5)

proto = PrototypeChain()
proto.add()
proto.add(1)

data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(spamFilter)
transactions.add(data)

verif: SignedVerification = SignedVerification(data.hash)
verif.sign(1, PrivateKey(1))

proto.add(packets=[VerificationPacket(data.hash, [0])])
for _ in range(6):
  proto.add()

vectors: IO[Any] = open("e2e/Vectors/Consensus/Verification/HundredFortyTwo.json", "w")
vectors.write(json.dumps({
  "blockchain": proto.toJSON(),
  "transactions": transactions.toJSON(),
  "verification": verif.toSignedJSON()
}))
vectors.close()
