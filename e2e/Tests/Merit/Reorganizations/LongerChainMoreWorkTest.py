from typing import Dict, List, Any
import json

from pytest import raises

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError
from e2e.Tests.Merit.Verify import verifyBlockchain

def LongerChainMoreWorkTest(
  rpc: RPC
) -> None:
  chains: Dict[str, List[Dict[str, Any]]]
  with open("e2e/Vectors/Merit/Reorganizations/LongerChainMoreWork.json", "r") as file:
    chains = json.loads(file.read())

  #Load the alternate blockchain.
  alt: Blockchain = Blockchain.fromJSON(chains["alt"])

  #Send the alternate tip.
  def sendAlternateTip() -> None:
    header: bytes = rpc.meros.liveBlockHeader(alt.blocks[-1].header)

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
      req = rpc.meros.sync.recv()
      if req != (MessageType.BlockHeaderRequest.toByte() + alt.blocks[diff].header.hash):
        raise TestError("Meros didn't request a previous BlockHeader.")
      rpc.meros.syncBlockHeader(alt.blocks[diff].header)
      diff += 1

    diff = -14
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

  with raises(SuccessError):
    Liver(
      rpc,
      chains["main"],
      callbacks={
        25: sendAlternateTip
      }
    ).live()
