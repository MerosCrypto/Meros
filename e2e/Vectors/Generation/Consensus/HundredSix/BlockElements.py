#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey

#Transaction classes.
from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

#SpamFilter class.
from e2e.Classes.Consensus.SpamFilter import SpamFilter

#Element classes.
from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty

#Blockchain classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain. Solely used to get the genesis Block hash.
blockchain: Blockchain = Blockchain()

#Block vectors.
blocks: List[Dict[str, Any]] = []

#Transactions.
transactions: Transactions = Transactions()

#Spam Filter.
dataFilter: SpamFilter = SpamFilter(5)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS Private Key.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

#Create a Data for the VerificationPacket.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(dataFilter)
transactions.add(data)

#Generate the VerificationPacket Block.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([VerificationPacket(data.hash, [1])]),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), [VerificationPacket(data.hash, [1])]),
    blsPrivKey.toPublicKey().serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([VerificationPacket(data.hash, [1])], [], blsPrivKey.sign(b""))
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it to the vectors.
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
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it to the vectors.
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
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it to the vectors.
blocks.append(block.toJSON())
print("Generated Hundred Six Block Elements DataDifficulty Block.")

result: Dict[str, Any] = {
  "blocks": blocks,
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/HundredSix/BlockElements.json", "w")
vectors.write(json.dumps(result))
vectors.close()
