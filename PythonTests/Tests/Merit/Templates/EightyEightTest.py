#https://github.com/MerosCrypto/Meros/issues/88

#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, Signature

#Merit classes.
from PythonTests.Classes.Merit.Blockchain import BlockHeader
from PythonTests.Classes.Merit.Blockchain import BlockBody
from PythonTests.Classes.Merit.Blockchain import Block
from PythonTests.Classes.Merit.Merit import Merit

#Consensus classes.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#Merit verifiers.
from PythonTests.Tests.Merit.Verify import verifyBlockchain

#Ed25519 lib.
import ed25519

#Sleep standard function.
from time import sleep

#JSON standard lib.
import json

#Blake2b standard function.
from hashlib import blake2b

#pylint: disable=too-many-locals,too-many-statements
def EightyEightTest(
    rpc: RPC
) -> None:
    #Ed25519 key.
    edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
    edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

    #BLS key.
    blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
    blsPubKey: str = blsPrivKey.toPublicKey().serialize().hex()

    #Blocks.
    file: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(file.read())
    file.close()

    #Merit.
    merit: Merit = Merit()
    #Spam Filter.
    dataFilter: SpamFilter = SpamFilter(5)

    #Handshake with the node.
    rpc.meros.liveConnect(merit.blockchain.blocks[0].header.hash)
    rpc.meros.syncConnect(merit.blockchain.blocks[0].header.hash)

    #Send the first Block.
    block: Block = Block.fromJSON(blocks[0])
    merit.blockchain.add(block)
    rpc.meros.liveBlockHeader(block.header)

    #Handle sync requests.
    reqHash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.sync.recv()
        if MessageType(msg[0]) == MessageType.BlockBodyRequest:
            reqHash = msg[1 : 33]
            if reqHash != block.header.hash:
                raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

            #Send the BlockBody.
            rpc.meros.blockBody(block)

            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    if MessageType(rpc.meros.live.recv()[0]) != MessageType.BlockHeader:
        raise TestError("Meros didn't broadcast the Block Header it just added.")

    #Create two Datas.
    datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
    datas.append(Data(datas[0].hash, b"Hello there! General Kenobi."))

    for data in datas:
        #Sign them and have them beat the spam filter.
        data.sign(edPrivKey)
        data.beat(dataFilter)

        #Transmit them.
        rpc.meros.liveTransaction(data)

    #Verify both.
    verifs: List[SignedVerification] = [
        SignedVerification(datas[0].hash),
        SignedVerification(datas[1].hash)
    ]
    for verif in verifs:
        verif.sign(0, blsPrivKey)

    #Only transmit the second.
    rpc.meros.signedElement(verifs[1])
    sleep(0.5)

    #Verify the block template has no verifications.
    if bytes.fromhex(
        rpc.call("merit", "getBlockTemplate", [blsPubKey])["header"]
    )[36 : 68] != bytes(32):
        raise TestError("Block template has Verification Packets.")

    #Transmit the first signed verification.
    rpc.meros.signedElement(verifs[0])
    sleep(0.5)

    #Verify the block template has both verifications.
    template: Dict[str, Any] = rpc.call(
        "merit",
        "getBlockTemplate",
        [blsPubKey]
    )
    template["header"] = bytes.fromhex(template["header"])
    packets: List[VerificationPacket] = [VerificationPacket(datas[0].hash, [0]), VerificationPacket(datas[1].hash, [0])]
    if template["header"][36 : 68] != BlockHeader.createContents(packets):
        raise TestError("Block template doesn't have both Verification Packets.")

    #Mine the Block.
    block = Block(
        BlockHeader(
            0,
            block.header.hash,
            BlockHeader.createContents(packets),
            1,
            template["header"][-43 : -39],
            BlockHeader.createSketchCheck(template["header"][-43 : -39], packets),
            0,
            int.from_bytes(template["header"][-4:], byteorder="big"),
        ),
        BlockBody(
            packets,
            [],
            Signature.aggregate([verifs[0].signature, verifs[1].signature])
        )
    )
    if block.header.serializeHash()[:-4] != template["header"]:
        raise TestError("Failed to recreate the header.")
    if block.body.serialize(
        block.header.sketchSalt,
        len(packets)
    ) != bytes.fromhex(template["body"]):
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
                block.body.serialize(block.header.sketchSalt, len(packets))
            ).hex()
        ]
    )

    #Verify the Blockchain.
    verifyBlockchain(rpc, merit.blockchain)
