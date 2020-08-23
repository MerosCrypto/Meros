from typing import Dict, List, IO, Any
from time import sleep
import json

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def ChainReorgDifferentKeyTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/RandomX/ChainReorgSameKey.json", "r")
  chains: Dict[str, List[Dict[str, Any]]] = json.loads(file.read())
  file.close()

  #Load the blockchains.
  main: Blockchain = Blockchain.fromJSON(chains["main"])
  alt: Blockchain = Blockchain.fromJSON(chains["alt"])

  #Send the alternate tip.
  def sendAlternateTip() -> None:
    rpc.meros.liveBlockHeader(alt.blocks[-1].header)

    req: bytes = rpc.meros.sync.recv()
    if MessageType(req[0]) != MessageType.BlockListRequest:
      raise TestError("Meros didn't request the list of previous BlockHeaders.")
    if req[3 : 35] != alt.blocks[-2].header.hash:
      raise TestError("Meros didn't request the list of previous BlockHeaders for THIS header.")

    blockList: List[bytes] = []
    b: int = len(alt.blocks) - 3
    while b != (len(alt.blocks) - 35):
      blockList.append(alt.blocks[b].header.hash)
      b -= 1
    rpc.meros.blockList(blockList)

    diff = -20
    while diff != -1:
      req = rpc.meros.sync.recv()
      if req != (MessageType.BlockHeaderRequest.toByte() + alt.blocks[diff].header.hash):
        raise TestError("Meros didn't request a previous BlockHeader.")
      rpc.meros.syncBlockHeader(alt.blocks[diff].header)
      diff += 1

    #Advance the chain far enough to switch to the new key.
    diff = -20
    while diff != -11:
      req = rpc.meros.sync.recv()
      if req != (MessageType.BlockBodyRequest.toByte() + alt.blocks[diff].header.hash):
        raise TestError("Meros didn't request a previous BlockBody.")
      rpc.meros.blockBody(alt.blocks[diff])
      diff += 1

    #Cause the reorganization to fail.
    if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockBodyRequest:
      raise TestError("Meros didn't request a BlockBody.")
    rpc.meros.dataMissing()

    sleep(65)
    rpc.meros.liveConnect(main.blocks[0].header.hash)
    rpc.meros.syncConnect(main.blocks[0].header.hash)

    #Sync back the regular chain.
    rpc.meros.liveBlockHeader(main.blocks[400].header)
    if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockListRequest:
      raise TestError("Meros didn't request the Block list.")
    blockList = []
    b = 398
    while b != 380:
      blockList.append(main.blocks[b].header.hash)
      b -= 1
    rpc.meros.blockList(blockList)

    for b in range(391, 400):
      if rpc.meros.sync.recv() != (MessageType.BlockHeaderRequest.toByte() + main.blocks[b].header.hash):
        raise TestError("Meros didn't request the BlockHeader.")
      rpc.meros.syncBlockHeader(main.blocks[b].header)

    for b in range(391, 401):
      if rpc.meros.sync.recv() != (MessageType.BlockBodyRequest.toByte() + main.blocks[b].header.hash):
        raise TestError("Meros didn't request the BlockBody.")
      rpc.meros.blockBody(main.blocks[b])

  Liver(
    rpc,
    chains["main"],
    callbacks={
      400: sendAlternateTip
    }
  ).live()
