#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey

#Merit classes.
from PythonTests.Classes.Merit.Blockchain import BlockHeader
from PythonTests.Classes.Merit.Blockchain import BlockBody
from PythonTests.Classes.Merit.Blockchain import Block
from PythonTests.Classes.Merit.Merit import Merit

#Element classes.
from PythonTests.Classes.Consensus.DataDifficulty import SignedDataDifficulty

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#Merit verifiers.
from PythonTests.Tests.Merit.Verify import verifyBlockchain

#Sleep standard function.
from time import sleep

#JSON standard lib.
import json

#Blake2b standard function.
from hashlib import blake2b

#pylint: disable=too-many-locals,too-many-statements
def TElementTest(
    rpc: RPC
) -> None:
    #BLS key.
    blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
    blsPubKey: str = blsPrivKey.toPublicKey().serialize().hex()

    #Blocks.
    file: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(file.read())
    file.close()

    #Merit.
    merit: Merit = Merit(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100
    )

    #Handshake with the node.
    rpc.meros.connect(254, 254, merit.blockchain.blocks[0].header.hash)

    #Send the first Block.
    block: Block = Block.fromJSON(merit.blockchain.keys, blocks[0])
    merit.blockchain.add(block)
    rpc.meros.blockHeader(block.header)

    #Handle sync requests.
    reqHash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.syncingAcknowledged()

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            reqHash = msg[1 : 33]
            if reqHash != block.header.hash:
                raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

            #Send the BlockBody.
            rpc.meros.blockBody(merit.state.nicks, block)

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            pass

        elif MessageType(msg[0]) == MessageType.BlockHeader:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Create and transmit a DataDifficulty.
    dataDiff: SignedDataDifficulty = SignedDataDifficulty(bytes.fromhex("00" * 32), 0, 0, blsPrivKey.toPublicKey())
    dataDiff.sign(0, blsPrivKey)
    rpc.meros.signedElement(dataDiff)
    sleep(0.5)

    #Verify the block template has the DataDifficulty.
    template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", [blsPubKey])
    template["header"] = bytes.fromhex(template["header"])
    if template["header"][36 : 68] != BlockHeader.createContents(merit.state.nicks, [], [dataDiff.toSignedElement()]):
        raise TestError("Block template doesn't have the Data Difficulty.")

    #Mine the Block.
    block = Block(
        BlockHeader(
            0,
            block.header.hash,
            BlockHeader.createContents(merit.state.nicks, [], [dataDiff.toSignedElement()]),
            1,
            template["header"][-43 : -39],
            BlockHeader.createSketchCheck(template["header"][-43 : -39], []),
            0,
            int.from_bytes(template["header"][-4:], byteorder="big"),
        ),
        BlockBody([], [dataDiff.toSignedElement()], dataDiff.signature)
    )
    if block.header.serializeHash()[:-4] != template["header"]:
        raise TestError("Failed to recreate the header.")
    if block.body.serialize(merit.state.nicks, block.header.sketchSalt) != bytes.fromhex(template["body"]):
        raise TestError("Failed to recreate the body.")

    block.mine(blsPrivKey, merit.blockchain.difficulty())
    merit.blockchain.add(block)

    #Publish it.
    rpc.call(
        "merit",
        "publishBlock",
        [
            template["id"],
            (
                template["header"] +
                block.header.proof.to_bytes(4, byteorder="big") +
                block.header.signature +
                block.body.serialize(merit.state.nicks, block.header.sketchSalt)
            ).hex()
        ]
    )

    #Verify the Blockchain.
    verifyBlockchain(rpc, merit.blockchain)
