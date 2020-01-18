#Tests proper handling of a MeritRemoval which has already been archived.

#Types.
from typing import Dict, List, IO, Any

#Block class.
from PythonTests.Classes.Merit.Block import Block

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#TestError and SuccessError Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#JSON standard lib.
import json

def RepeatTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Repeat.json", "r")
    vectors: List[Dict[str, Any]] = json.loads(file.read())
    file.close()

    keys: Dict[bytes, int] = {
        bytes.fromhex(vectors[0]["header"]["miner"]): 0
    }

    def sendBlock() -> None:
        #Send the Block with the MeritRemoval archived again.
        block: Block = Block.fromJSON(keys, vectors[-1])
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
                raise SuccessError("Meros didn't add the same MeritRemoval twice.")

            if MessageType(msg[0]) == MessageType.Syncing:
                rpc.meros.syncingAcknowledged()

            elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                reqHash = msg[1 : 33]
                if reqHash != block.header.hash:
                    raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

                #Send the BlockBody.
                blockBodySynced = True
                rpc.meros.blockBody([], block)

            elif MessageType(msg[0]) == MessageType.SyncingOver:
                pass

            elif MessageType(msg[0]) == MessageType.BlockHeader:
                #Raise a TestError if the Block was added.
                raise TestError("Meros synced a Block with a repeat MeritRemoval.")

            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

    Liver(
        rpc,
        vectors,
        callbacks={
            3: sendBlock
        }
    ).live()
