#Types.
from typing import IO, Dict, List, Any

#Transactions classes.
from python_tests.Classes.Transactions.Claim import Claim
from python_tests.Classes.Transactions.Data import Data
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.Consensus import Consensus

#Merit classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Merit import Merit

#Ed25519 lib.
import ed25519

#BLS lib.
import blspy

#Time standard function.
from time import time

#JSON standard lib.
import json

#Blank Blocks.
bbFile: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "r")
blankBlocks: List[Dict[str, Any]] = json.loads(bbFile.read())
bbFile.close()

#Transactions.
transactions: Transactions = Transactions()
#$Consensus.
consensus: Consensus = Consensus(
    bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
)
#Merit.
merit: Merit = Merit(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
    100
)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
blsPubKey: blspy.PublicKey = blsPrivKey.get_public_key()

#Add 13 Blank Blocks.
for i in range(13):
    merit.add(transactions, consensus, Block.fromJSON(blankBlocks[i]))

#Create the Data.
data: Data = Data(
    edPubKey.to_bytes().rjust(48, b'\0'),
    bytes()
)
data.sign(edPrivKey)
data.beat(consensus.dataFilter)
data.verified = True
transactions.add(data)

#Verify it.
verif: SignedVerification = SignedVerification(data.hash)
verif.sign(blsPrivKey, 0)
consensus.add(verif)

#Generate another 6 Blocks.
#Next block should have a record.
block: Block = Block(
    BlockHeader(
        14,
        merit.blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [(blsPubKey, 0, -1)]
        )
    ),
    BlockBody([
        (
            blsPubKey,
            0,
            consensus.getMerkle(
                blsPubKey,
                0
            )
        )
    ])
)
for i in range(15, 21):
    #Mine it.
    block.mine(merit.blockchain.difficulty)

    #Add it.
    merit.add(transactions, consensus, block)
    print("Generated Claimed Mint Block " + str(block.header.nonce) + ".")

    #Create the next Block.
    block = Block(
        BlockHeader(
            i,
            merit.blockchain.last(),
            int(time())
        ),
        BlockBody()
    )

#Claim the new Mint.
claim: Claim = Claim(
    [merit.mints[0].hash],
    edPubKey.to_bytes()
)
claim.amount = merit.mints[0].output[1]
claim.sign([blsPrivKey])
claim.verified = True
transactions.add(claim)

#Verify the Claim..
verif = SignedVerification(claim.hash)
verif.sign(blsPrivKey, 1)
consensus.add(verif)

#Mine one more Block.
block = Block(
    BlockHeader(
        20,
        merit.blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [(blsPubKey, 1, -1)]
        )
    ),
    BlockBody([
        (
            blsPubKey,
            1,
            consensus.getMerkle(
                blsPubKey,
                1
            )
        )
    ])
)
block.mine(merit.blockchain.difficulty)
merit.add(transactions, consensus, block)
print("Generated Claimed Mint Block " + str(block.header.nonce) + ".")

result: Dict[str, Any] = {
    "blockchain": merit.blockchain.toJSON(),
    "transactions": transactions.toJSON(),
    "consensus":  consensus.toJSON()
}
vectors: IO[Any] = open("python_tests/Vectors/Transactions/ClaimedMint.json", "w")
vectors.write(json.dumps(result))
vectors.close()
