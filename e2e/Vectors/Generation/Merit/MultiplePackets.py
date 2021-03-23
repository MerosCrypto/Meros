#Generate a Blocks with multiple VerificationPackets for the same Transaction - these should be invalid.
import json

import ed25519

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

#Generate a chain with 2 Merit Holders.
proto: PrototypeChain = PrototypeChain(1)
proto.add(1)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#Create a Data.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(SpamFilter(5))
proto.add(packets=[VerificationPacket(data.hash, [0]), VerificationPacket(data.hash, [1])])

with open("e2e/Vectors/Merit/MultiplePackets.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "data": data.toJSON()
  }))
