from typing import IO, Dict, List, Any
import json

import ed25519

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock

merit: Merit = Merit()
blocks: List[Dict[str, Any]] = []

transactions: Transactions = Transactions()

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(0)

#Generate a Data to verify for the VerificationPacket Block.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(dataFilter)
transactions.add(data)
packet: VerificationPacket = VerificationPacket(data.hash, [1])

blocks.append(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(data.hash, [1])],
    minerID=blsPrivKey
  ).finish(0, merit).toJSON()
)

#Generate the SendDifficulty Block.
blocks.append(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    elements=[SendDifficulty(0, 0, 1)],
    minerID=blsPrivKey
  ).finish(0, merit).toJSON()
)

#Generate the DataDifficulty Block.
blocks.append(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    elements=[DataDifficulty(0, 0, 1)],
    minerID=blsPrivKey
  ).finish(0, merit).toJSON()
)

result: Dict[str, Any] = {
  "blocks": blocks,
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/HundredSix/BlockElements.json", "w")
vectors.write(json.dumps(result))
vectors.close()
