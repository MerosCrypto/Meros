#Tests proper handling of Verifications with Transactions which don't exist.

#Types.
from typing import Dict, List, IO, Any

#Sketch class.
from PythonTests.Libs.Minisketch import Sketch

#Merit classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Merit import Merit

#VerificationPacket class.
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.Liver import Liver

#JSON standard lib.
import json

#pylint: disable=too-many-statements
def VUnknownTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Parsable.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Merit.
    merit: Merit = Merit.fromJSON(vectors["blockchain"])

    #Custom function to send the last Block and verify it errors at the right place.
    def checkFail() -> None:
        #This Block should cause the node to disconnect us AFTER it attempts to sync our Transaction.
        syncedTX: bool = False

        #Grab the Block.
        block: Block = merit.blockchain.blocks[2]

        #Send the Block.
        rpc.meros.liveBlockHeader(block.header)

        #Handle sync requests.
        reqHash: bytes = bytes()
        while True:
            if syncedTX:
                #Try receiving from the Live socket, where Meros sends keep-alives.
                try:
                    if len(rpc.meros.live.recv()) != 0:
                        raise Exception()
                except TestError:
                    raise SuccessError("Node disconnected us after we sent a parsable, yet invalid, Verification.")
                except Exception:
                    raise TestError("Meros sent a keep-alive.")

            msg: bytes = rpc.meros.sync.recv()
            if MessageType(msg[0]) == MessageType.BlockBodyRequest:
                reqHash = msg[1 : 33]
                if reqHash != block.header.hash:
                    raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

                #Send the BlockBody.
                rpc.meros.blockBody(merit.state.nicks, block)

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
                rpc.meros.dataMissing()
                syncedTX = True

            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Create and execute a Liver.
    Liver(rpc, vectors["blockchain"], callbacks={1: checkFail}).live()
