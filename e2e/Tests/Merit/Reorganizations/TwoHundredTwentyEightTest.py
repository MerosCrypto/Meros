from typing import Dict, List, IO, Any
from time import sleep
import json

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType, MerosSocket
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def TwoHundredTwentyEightTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/ShorterChainMoreWork.json", "r")
  chains: Dict[str, List[Dict[str, Any]]] = json.loads(file.read())
  file.close()

  #Load the Blockchains.
  main: Blockchain = Blockchain.fromJSON(chains["main"])
  alt: Blockchain = Blockchain.fromJSON(chains["alt"])

  def send16AndInvalidAlt() -> None:
    #Send the Block after the fork from the main chain.
    header: bytes = rpc.meros.liveBlockHeader(main.blocks[16].header)
    req: bytes = rpc.meros.sync.recv()
    if req != (MessageType.BlockBodyRequest.toByte() + main.blocks[16].header.hash):
      raise TestError("Meros didn't request the BlockBody for this Block from the main chain.")
    rpc.meros.blockBody(main.blocks[16])
    if rpc.meros.live.recv() != header:
      raise TestError("Meros didn't send back the BlockHeader.")

    #Send the headers of the alt chain to trigger a re-org.
    header = rpc.meros.liveBlockHeader(alt.blocks[-1].header)
    req = rpc.meros.sync.recv()
    if MessageType(req[0]) != MessageType.BlockListRequest:
      raise TestError("Meros didn't request the list of previous BlockHeaders.")
    if req[3 : 35] != alt.blocks[-2].header.hash:
      raise TestError("Meros didn't request the list of previous BlockHeaders for THIS header.")

    blockList: List[bytes] = []
    b: int = len(alt.blocks) - 3
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

    #Meros should now revert and attempt the re-org.
    #Disconnect to make sure it fails.
    rpc.meros.live.connection.close()
    rpc.meros.sync.connection.close()

    #Sleep long enough to get counted as disconnected and removed from the list of connections.
    sleep(35)

    #Reconnect.
    rpc.meros.live = MerosSocket(rpc.meros.tcp, 254, 254, True, main.blocks[15].header.hash)
    rpc.meros.sync = MerosSocket(rpc.meros.tcp, 254, 254, False, main.blocks[15].header.hash)

    #The Liver will now send Block 16 again. The trick is whether or not it can add 16.
    #If it can't, because it didn't prune the Data, this issue is still valid.

  #This is based off the ShorterChainMoreWork test.
  #While that test syncs the full chain A, it then syncs the alt chain.
  #As this chain tests a failed re-org attempt, we can stay on the main chain and fully verify it.
  #So instead of syncing the full chain, we go to right before the fork, and manually sync the forked Block.
  #Then we trigger the re-org, cause it to fail, preserving the revert.
  #Then the Liver syncs the rest of the main chain, unaware of this.
  Liver(
    rpc,
    chains["main"],
    callbacks={
      15: send16AndInvalidAlt
    }
  ).live()
