#https://github.com/MerosCrypto/Meros/issues/106. Specifically tests elements in Blocks (except MeritRemovals).

#Types.
from typing import Dict, List, IO, Any

#Sketch class.
from PythonTests.Libs.Minisketch import Sketch

#Blockchain classes.
from PythonTests.Classes.Merit.Blockchain import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#VerificationPacket class.
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Meros import MessageType

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#JSON standard lib.
import json

#pylint: disable=too-many-statements
def HundredSixBlockElementsTest(
    rpc: RPC
) -> None:
    #Load the vectors.
    file: IO[Any] = open("PythonTests/Vectors/Consensus/HundredSix/BlockElements.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Blockchain. Solely used to get the genesis Block hash.
    blockchain: Blockchain = Blockchain()

    #Transactions.
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

    #Parse the Blocks from the vectors.
    blocks: List[Block] = []
    for block in vectors["blocks"]:
        blocks.append(Block.fromJSON({}, block))

    for block in blocks:
        #Handshake with the node.
        rpc.meros.connect(254, 254, blockchain.blocks[0].header.hash)

        #Send the Block.
        rpc.meros.blockHeader(block.header)

        #Flag of if the Block's Body synced.
        blockBodySynced: bool = False

        #Handle sync requests.
        reqHash: bytes = bytes()
        while True:
            try:
                msg: bytes = rpc.meros.recv()
            except TestError:
                if not blockBodySynced:
                    raise TestError("Node disconnected us before syncing the body.")

                #Verify the node didn't crash.
                try:
                    if rpc.call("merit", "getHeight") != 1:
                        raise Exception()
                except Exception:
                    raise TestError("Node crashed after being sent a malformed Element.")

                #Since the node didn't crash, break out of this loop to trigger the next test case.
                break

            if MessageType(msg[0]) == MessageType.Syncing:
                rpc.meros.syncingAcknowledged()

            elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                reqHash = msg[1 : 33]
                if reqHash != block.header.hash:
                    raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

                #Send the BlockBody.
                blockBodySynced = True
                rpc.meros.blockBody([], block)

            elif MessageType(msg[0]) == MessageType.SketchHashesRequest:
                if not block.body.packets:
                    raise TestError("Meros asked for Sketch Hashes from a Block without any.")

                reqHash = msg[1 : 33]
                if reqHash != block.header.hash:
                    raise TestError("Meros asked for Sketch Hashes that didn't belong to the Block we just sent it.")

                #Create the haashes.
                hashes: List[int] = []
                for packet in block.body.packets:
                    hashes.append(Sketch.hash(block.header.sketchSalt, packet))

                #Send the Sketch Hashes.
                rpc.meros.sketchHashes(hashes)

            elif MessageType(msg[0]) == MessageType.SketchHashRequests:
                if not block.body.packets:
                    raise TestError("Meros asked for Verification Packets from a Block without any.")

                reqHash = msg[1 : 33]
                if reqHash != block.header.hash:
                    raise TestError("Meros asked for Verification Packets that didn't belong to the Block we just sent it.")

                #Create a lookup of hash to packets.
                packets: Dict[int, VerificationPacket] = {}
                for packet in block.body.packets:
                    packets[Sketch.hash(block.header.sketchSalt, packet)] = packet

                #Look up each requested packet and respond accordingly.
                for h in range(int.from_bytes(msg[33 : 37], byteorder="big")):
                    sketchHash: int = int.from_bytes(msg[37 + (h * 8) : 45 + (h * 8)], byteorder="big")
                    if sketchHash not in packets:
                        raise TestError("Meros asked for a non-existent Sketch Hash.")
                    rpc.meros.packet(packets[sketchHash])

            elif MessageType(msg[0]) == MessageType.TransactionRequest:
                reqHash = msg[1 : 33]

                if reqHash not in transactions.txs:
                    raise TestError("Meros asked for a non-existent Transaction.")

                rpc.meros.transaction(transactions.txs[reqHash])

            elif MessageType(msg[0]) == MessageType.SyncingOver:
                pass

            elif MessageType(msg[0]) == MessageType.BlockHeader:
                #Raise a TestError if the Block was added.
                raise TestError("Meros synced a Block with an invalid holder.")

            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

        #Reset the node.
        rpc.reset()
