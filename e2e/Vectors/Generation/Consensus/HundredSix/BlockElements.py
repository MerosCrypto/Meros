from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock

blockchain: Blockchain = Blockchain()
blocks: List[Dict[str, Any]] = []

transactions: Transactions = Transactions()

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]

#Generate a Data to verify for the VerificationPacket Block.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(dataFilter)
transactions.add(data)

blocks.append(
  PrototypeBlock(
    blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(data.hash, [1])],
    minerID=blsPrivKeys[0]
  ).finish(
    False,
    blockchain.genesis,
    blockchain.blocks[-1].header,
    blockchain.difficulty(),
    blsPrivKeys
  ).toJSON()
)

#Generate the SendDifficulty Block.
blocks.append(
  PrototypeBlock(
    blockchain.blocks[-1].header.time + 1200,
    elements=[SendDifficulty(0, 0, 1)],
    minerID=blsPrivKeys[0]
  ).finish(
    False,
    blockchain.genesis,
    blockchain.blocks[-1].header,
    blockchain.difficulty(),
    blsPrivKeys
  ).toJSON()
)

#Generate the DataDifficulty Block.
blocks.append(
  PrototypeBlock(
    blockchain.blocks[-1].header.time + 1200,
    elements=[DataDifficulty(0, 0, 1)],
    minerID=blsPrivKeys[0]
  ).finish(
    False,
    blockchain.genesis,
    blockchain.blocks[-1].header,
    blockchain.difficulty(),
    blsPrivKeys
  ).toJSON()
)

result: Dict[str, Any] = {
  "blocks": blocks,
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/HundredSix/BlockElements.json", "w")
vectors.write(json.dumps(result))
vectors.close()
