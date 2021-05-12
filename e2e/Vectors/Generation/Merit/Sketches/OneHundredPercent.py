from typing import Dict, List, Any
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

privKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
pubKey: bytes = privKey.get_verifying_key()

spamFilter: SpamFilter = SpamFilter(5)

proto: PrototypeChain = PrototypeChain(1, keepUnlocked=False)

data: Data = Data(bytes(32), pubKey)
datas: List[Dict[str, Any]] = []
verifs: List[Dict[str, Any]] = []
for _ in range(5):
  data.sign(privKey)
  data.beat(spamFilter)
  datas.append(data.toJSON())

  verif: SignedVerification = SignedVerification(data.hash)
  verif.sign(0, PrivateKey(0))
  verifs.append(verif.toSignedJSON())
  data = Data(data.hash, bytes(1))

proto.add(0, [VerificationPacket(bytes.fromhex(data["hash"]), [0]) for data in datas])

with open("e2e/Vectors/Merit/Sketches/OneHundredPercent.json", "w") as vectors:
  vectors.write(
    json.dumps({
      "blockchain": proto.toJSON(),
      "datas": datas,
      "verifications": verifs
    })
  )
