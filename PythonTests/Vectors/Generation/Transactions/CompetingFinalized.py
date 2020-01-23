#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey, Signature

#Transactions classes.
from PythonTests.Classes.Transactions.Data import Data
from PythonTests.Classes.Transactions.Transactions import Transactions

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#SignedVerification and VerificationPacket classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Merit classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Merit import Merit

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blank Blocks.
bbFile: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
blankBlocks: List[Dict[str, Any]] = json.loads(bbFile.read())
bbFile.close()

#Transactions.
transactions: Transactions = Transactions()
#Merit.
merit: Merit = Merit()

#SpamFilter.
dataFilter: SpamFilter = SpamFilter(bytes.fromhex("CC" * 32))

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Add 1 Blank Block.
for i in range(1):
    merit.add(Block.fromJSON(merit.blockchain.keys, blankBlocks[i]))

#Create the Data and a successor.
first: Data = Data(bytes(32), edPubKey.to_bytes())
first.sign(edPrivKey)
first.beat(dataFilter)
transactions.add(first)

second: Data = Data(first.hash, bytes(1))
second.sign(edPrivKey)
second.beat(dataFilter)
transactions.add(second)

#Verify them.
firstVerif: SignedVerification = SignedVerification(first.hash)
firstVerif.sign(0, blsPrivKey)

secondVerif: SignedVerification = SignedVerification(second.hash)
secondVerif.sign(0, blsPrivKey)

packets: List[VerificationPacket] = [
    VerificationPacket(first.hash, [0]),
    VerificationPacket(second.hash, [0]),
]

#Generate another 6 Blocks.
#Next block should have the packets.
block: Block = Block(
    BlockHeader(
        0,
        merit.blockchain.last(),
        BlockHeader.createContents([], packets),
        1,
        bytes(4),
        BlockHeader.createSketchCheck(bytes(4), packets),
        0,
        merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody(packets, [], Signature.aggregate([firstVerif.signature, secondVerif.signature]))
)
for _ in range(6):
    #Mine it.
    block.mine(blsPrivKey, merit.blockchain.difficulty())

    #Add it.
    merit.add(block)
    print("Generated Competing Finalized Block " + str(len(merit.blockchain.blocks) - 1) + ".")

    #Create the next Block.
    block = Block(
        BlockHeader(
            0,
            merit.blockchain.last(),
            bytes(32),
            1,
            bytes(4),
            bytes(32),
            0,
            merit.blockchain.blocks[-1].header.time + 1200
        ),
        BlockBody()
    )

#Create a Data competing with the now-finalized second Data.
competitor: Data = Data(first.hash, bytes(2))
competitor.sign(edPrivKey)
competitor.beat(dataFilter)
transactions.add(competitor)

#Verify it.
competitorVerif: SignedVerification = SignedVerification(competitor.hash)
competitorVerif.sign(0, blsPrivKey)

#Mine one more Block.
block = Block(
    BlockHeader(
        0,
        merit.blockchain.last(),
        BlockHeader.createContents([], [VerificationPacket(competitor.hash, [0])]),
        1,
        bytes(4),
        BlockHeader.createSketchCheck(bytes(4), [VerificationPacket(competitor.hash, [0])]),
        0,
        merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([VerificationPacket(competitor.hash, [0])], [], competitorVerif.signature)
)
block.mine(blsPrivKey, merit.blockchain.difficulty())
merit.add(block)
print("Generated Competing Finalized Block " + str(len(merit.blockchain.blocks) - 1) + ".")

result: Dict[str, Any] = {
    "blockchain": merit.blockchain.toJSON(),
    "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Transactions/CompetingFinalized.json", "w")
vectors.write(json.dumps(result))
vectors.close()
