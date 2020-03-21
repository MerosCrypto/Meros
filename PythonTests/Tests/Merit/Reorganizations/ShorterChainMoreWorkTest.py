#Types.
from typing import Dict, List, IO, Any

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#TestError and SuccessError Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#Blockchain verifier.
from PythonTests.Tests.Merit.Verify import verifyBlockchain

#JSON standard lib.
import json

def ShorterChainMoreWorkTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Merit/Reorganizations/ShorterChainMoreWork.json", "r")
    chains: Dict[str, List[Dict[str, Any]]] = json.loads(file.read())
    file.close()

    #Load the alternate blockchain.
    alt: Blockchain = Blockchain.fromJSON(chains["alt"])

    #Send the alternate tip.
    def sendAlternateTip() -> None:
        header: bytes = rpc.meros.liveBlockHeader(alt.blocks[-1].header)

        req: bytes = rpc.meros.sync.recv()
        if MessageType(req[0]) != MessageType.BlockListRequest:
            raise TestError("Meros didn't request the list of previous BlockHeaders.")
        if req[3 : 51] != alt.blocks[-1].header.hash:
            raise TestError("Meros didn't request the list of previous BlockHeaders for THIS header.")

        blockList: List[bytes] = []
        b: int = len(alt.blocks) - 2
        while b != -1:
            blockList.append(alt.blocks[b].header.hash)
            b -= 1
        rpc.meros.blockList(blockList)

        diff = -4
        while diff != -1:
            req = rpc.meros.sync.recv()
            if req != (MessageType.BlockHeaderRequest.toByte() + alt.blocks[diff].header.hash):
                raise TestError("Meros didn't request a previous BlockHeader.")
            rpc.meros.syncBlockHeader(alt.blocks[diff].header)
            diff += 1

        diff = -4
        while diff != 0:
            req = rpc.meros.sync.recv()
            if req != (MessageType.BlockBodyRequest.toByte() + alt.blocks[diff].header.hash):
                raise TestError("Meros didn't request a previous BlockBody.")
            rpc.meros.blockBody(alt.blocks[diff])
            diff += 1

        if rpc.meros.live.recv() != header:
            raise TestError("Meros didn't send back the BlockHeader.")

        #Verify the alternate Blockchain.
        verifyBlockchain(rpc, alt)

        #Raise SuccessError so the Liver doesn't fail when verifying the original chain.
        raise SuccessError("Meros re-organized to the alternate chain.")

    #Create and execute a Liver.
    Liver(
        rpc,
        chains["main"],
        callbacks={
            25: sendAlternateTip
        }
    ).live()
