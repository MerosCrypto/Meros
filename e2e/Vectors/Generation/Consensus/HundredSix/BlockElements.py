from typing import IO, Dict, List, Any

from hashlib import blake2b
import json

import ed25519

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Solely used to get the genesis Block hash.
blockchain: Blockchain = Blockchain()
blocks: List[Dict[str, Any]] = []

transactions: Transactions = Transactions()

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

#Create a Data for a VerificationPacket.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(dataFilter)
transactions.add(data)
packet: VerificationPacket = VerificationPacket(data.hash, [1])

#Generate the VerificationPacket Block.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([packet]),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), [packet]),
    blsPrivKey.toPublicKey().serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([packet], [], blsPrivKey.sign(b""))
)
block.mine(blsPrivKey, blockchain.difficulty())
blocks.append(block.toJSON())
print("Generated Hundred Six Block Elements VerificationPacket Block.")

#Generate the SendDifficulty Block.
elements: List[Element] = []
elements.append(SendDifficulty(0, 0, 1))
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], elements),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), []),
    blsPrivKey.toPublicKey().serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], elements, blsPrivKey.sign(b""))
)
block.mine(blsPrivKey, blockchain.difficulty())
blocks.append(block.toJSON())
print("Generated Hundred Six Block Elements SendDifficulty Block.")

#Generate the DataDifficulty Block.
elements = []
elements.append(DataDifficulty(0, 0, 1))
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], elements),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), []),
    blsPrivKey.toPublicKey().serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], elements, blsPrivKey.sign(b""))
)
block.mine(blsPrivKey, blockchain.difficulty())
blocks.append(block.toJSON())
print("Generated Hundred Six Block Elements DataDifficulty Block.")

result: Dict[str, Any] = {
  "blocks": blocks,
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/HundredSix/BlockElements.json", "w")
vectors.write(json.dumps(result))
vectors.close()
