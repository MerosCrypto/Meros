#https://github.com/MerosCrypto/Meros/issues/100

#Types.
from typing import Dict, List, IO, Any

#Merit class.
from PythonTests.Classes.Merit.Merit import Merit

#TestError and SuccessError Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#JSON standard lib.
import json

def HundredTest(
    rpc: RPC
) -> None:
    #Blocks.
    file: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(file.read())
    file.close()

    #Grab only the first block.
    blocks = [blocks[0]]

    #Merit.
    merit: Merit = Merit.fromJSON(blocks)

    #The normal flow would be:
    #Handshake
    #BlockHeaderRequest

    #We need to delay the BlockHeader. Then, Meros should send:
    #Handshake
    #BlockHeaderRequest
    #Handshake

    #EXCEPT Meros can't handle sending Handshakes after Requests like that (see issue #100).
    #Therefore, Meros won't send a Handshake if it has a pending request (totally valid and acceptable behavior).
    #This test verifies we get disconnected without a Handshake attempt.

    #Handshake with the node.
    rpc.meros.connect(254, 254, merit.blockchain.blocks[1].header.hash)

    #Handle sync requests.
    reqHash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.syncingAcknowledged()

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            reqHash = msg[1 : 33]
            if reqHash != merit.blockchain.blocks[-1].header.hash:
                raise TestError("Meros asked for a BlockHeader other than the one in the Block from the Handshake.")

            #Wait until Meros disconnects us.
            try:
                rpc.meros.recv()
            except TestError:
                raise SuccessError("Meros didn't attempt to handshake with us while it had a pending sync request.")
            raise TestError("Meros tried to handshake with us while it had a pending sync request.")
