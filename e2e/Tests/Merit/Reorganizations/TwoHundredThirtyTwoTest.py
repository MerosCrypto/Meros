from typing import Dict, List, Any

from time import sleep
from subprocess import Popen
import socket
import json

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError
from e2e.Tests.Merit.Verify import verifyBlockchain

def TwoHundredThirtyTwoTest(
  rpc: RPC
) -> None:
  chains: Dict[str, List[Dict[str, Any]]]
  with open("e2e/Vectors/Merit/Reorganizations/TwoHundredThirtyTwo.json", "r") as file:
    chains = json.loads(file.read())
  main: Blockchain = Blockchain.fromJSON(chains["main"])
  alt: Blockchain = Blockchain.fromJSON(chains["alt"])

  def sendBlock(
    toSend: Block
  ) -> None:
    rpc.meros.liveBlockHeader(toSend.header)
    rpc.meros.handleBlockBody(toSend)
    if toSend.body.packets:
      if rpc.meros.sync.recv() != (
        MessageType.SketchHashRequests.toByte() +
        toSend.header.hash +
        (1).to_bytes(4, byteorder="little") +
        Sketch.hash(toSend.header.sketchSalt, toSend.body.packets[0]).to_bytes(8, byteorder="little")
      ):
        raise TestError("Meros didn't ask for this BlockBody's VerificationPacket.")
      rpc.meros.packet(toSend.body.packets[0])

  #Make the initial connection and sync the main chain.
  rpc.meros.liveConnect(main.blocks[0].header.hash)
  rpc.meros.syncConnect(main.blocks[0].header.hash)
  sendBlock(main.blocks[1])
  sendBlock(main.blocks[2])

  #Trigger the reorganization to the alternate chain.
  #We only want the revert aspect of this.
  rpc.meros.liveBlockHeader(alt.blocks[3].header)
  if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockListRequest:
    raise TestError("Meros didn't ask for the Block List of the alternate chain.")
  rpc.meros.blockList([alt.blocks[1].header.hash])
  if rpc.meros.sync.recv() != (MessageType.BlockHeaderRequest.toByte() + alt.blocks[2].header.hash):
    raise TestError("Meros didn't ask for the other BlockHeader in this alternate chain.")
  rpc.meros.syncBlockHeader(alt.blocks[2].header)

  #Cause the re-organization to fail.
  rpc.meros.live.connection.close()
  rpc.meros.sync.connection.close()
  sleep(35)

  #Reboot the node to reload the database.
  rpc.meros.quit()

  #Reset the RPC's tracking variables.
  rpc.meros.calledQuit = False
  rpc.meros.process = Popen(["./build/Meros", "--data-dir", rpc.meros.dataDir, "--log-file", rpc.meros.log, "--db", rpc.meros.db, "--network", "devnet", "--token", "TEST_TOKEN", "--tcp-port", str(rpc.meros.tcp), "--rpc-port", str(rpc.meros.rpc), "--no-gui"])
  while True:
    try:
      connection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      connection.connect(("127.0.0.1", rpc.meros.rpc))
      connection.shutdown(socket.SHUT_RDWR)
      connection.close()
      break
    except ConnectionRefusedError:
      sleep(1)

  rpc.meros.liveConnect(main.blocks[0].header.hash)
  rpc.meros.syncConnect(main.blocks[0].header.hash)
  sendBlock(main.blocks[2])

  verifyBlockchain(rpc, main)
