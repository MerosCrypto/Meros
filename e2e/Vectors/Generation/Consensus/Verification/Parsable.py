from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

blockchain: Blockchain = Blockchain()

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Add a single Block to create Merit.
bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain.add(Block.fromJSON(blocks[0]))
bbFile.close()

#Create a Data with an invalid signature.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.signature = edPrivKey.sign(b"INVALID")
data.beat(dataFilter)

#Create a Verification.
sv: SignedVerification = SignedVerification(data.hash)
sv.sign(0, blsPrivKey)

#Create packets out of the Verification.
packets: List[VerificationPacket] = [VerificationPacket(data.hash, [0])]

#Generate another Block.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents(packets),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packets),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packets, [], sv.signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated Parsable Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "data":     data.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/Verification/Parsable.json", "w")
vectors.write(json.dumps(result))
vectors.close()
