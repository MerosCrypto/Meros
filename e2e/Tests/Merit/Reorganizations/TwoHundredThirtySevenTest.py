from typing import IO, Dict, List, Any

import json

from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def TwoHundredThirtySevenTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/TwoHundredThirtySeven.json", "r")
  chains: Dict[str, List[Dict[str, Any]]] = json.loads(file.read())
  main: Blockchain = Blockchain.fromJSON(chains["main"])
  alt: Blockchain = Blockchain.fromJSON(chains["alt"])
  file.close()

  def sendBlock(
    toSend: Block
  ) -> None:
    rpc.meros.liveBlockHeader(toSend.header)
    if rpc.meros.sync.recv() != (MessageType.BlockBodyRequest.toByte() + toSend.header.hash):
      raise TestError("Meros didn't ask for this Block's body.")
    rpc.meros.blockBody(toSend)

  #Send 0 through 3 of the main chain.
  rpc.meros.liveConnect(main.blocks[0].header.hash)
  rpc.meros.syncConnect(main.blocks[0].header.hash)
  sendBlock(main.blocks[1])
  sendBlock(main.blocks[2])
  sendBlock(main.blocks[3])

  #Send the alt chain, which won't have enough work to trigger a reorganization.
  rpc.meros.liveBlockHeader(alt.blocks[2].header)
  if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockListRequest:
    raise TestError("Meros didn't request for the Block List for this alternate chain.")
  rpc.meros.blockList([alt.blocks[0].header.hash])
  if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockHeaderRequest:
    raise TestError("Meros didn't request a BlockHeader in this alternate chain.")
  rpc.meros.syncBlockHeader(alt.blocks[1].header)

  #Verify Meros can sync the final Block.
  sendBlock(main.blocks[4])
