from typing import Dict, List, Any
from time import sleep
import json

from pytest import raises

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError
from e2e.Tests.Merit.Verify import verifyBlockchain

def THFSLessWorkTest(
  rpc: RPC
) -> None:
  chains: Dict[str, List[Dict[str, Any]]]
  with open("e2e/Vectors/Merit/Reorganizations/LongerChainMoreWork.json", "r") as file:
    chains = json.loads(file.read())

  #Load the alternate blockchain.
  alt: Blockchain = Blockchain.fromJSON(chains["alt"])

  #Load a chain of the fork point.
  forkPoint: Blockchain = Blockchain.fromJSON(chains["main"][0 : 15])

  #Send the alternate tip.
  def sendAlternateTip() -> None:
    rpc.meros.liveBlockHeader(alt.blocks[-1].header)

    req: bytes = rpc.meros.sync.recv()
    if MessageType(req[0]) != MessageType.BlockListRequest:
      raise TestError("Meros didn't request the list of previous BlockHeaders.")
    if req[-32:] != alt.blocks[-2].header.hash:
      raise TestError("Meros didn't request the list of previous BlockHeaders for THIS header.")

    blockList: List[bytes] = []
    b: int = len(alt.blocks) - 3
    while b != -1:
      blockList.append(alt.blocks[b].header.hash)
      b -= 1
    rpc.meros.blockList(blockList)

    diff = -14
    while diff != -1:
      if rpc.meros.sync.recv() != (MessageType.BlockHeaderRequest.toByte() + alt.blocks[diff].header.hash):
        raise TestError("Meros didn't request a previous BlockHeader.")
      rpc.meros.syncBlockHeader(alt.blocks[diff].header)
      diff += 1

    #Meros will now attempt the re-org, having verified the work.
    #Break the chain early via a data missing.
    diff = -14
    while diff != 0:
      if diff == -10:
        if rpc.meros.sync.recv()[:-4] != (MessageType.BlockBodyRequest.toByte() + alt.blocks[diff].header.hash):
          raise TestError("Meros didn't request a previous BlockBody.")
        rpc.meros.dataMissing()
        sleep(35)
        for socket in [rpc.meros.live, rpc.meros.sync]:
          socket.connection.close()
        #We could just edit the condition above, yet this keeps parity with the other reorg tests.
        break
      else:
        rpc.meros.handleBlockBody(alt.blocks[diff])
      diff += 1

    #Verify Meros at least went back to the fork point.
    #Ideally, it'd go back to the original chain.
    #Or if we synced enough blocks where we still have a chain with more work, we should remain on it.
    verifyBlockchain(rpc, forkPoint)
    raise SuccessError("Meros reverted back to the fork point.")

  with raises(SuccessError):
    Liver(
      rpc,
      chains["main"],
      callbacks={
        25: sendAlternateTip
      }
    ).live()
