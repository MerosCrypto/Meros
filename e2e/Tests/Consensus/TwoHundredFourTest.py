from typing import Dict, Any
from time import sleep
import json

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

from e2e.Tests.Errors import TestError

def TwoHundredFourTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/TwoHundredFour.json", "r") as file:
    vectors = json.loads(file.read())

  #Instantiate a Blockchain to set the RandomX key.
  chain: Blockchain = Blockchain()
  blank: Block = Block.fromJSON(vectors["blank"])

  if len(vectors["blocks"]) != 1:
    raise Exception("Misread this test's vectors, creating an invalid test due to that.")
  block: Block = Block.fromJSON(vectors["blocks"][0])

  rpc.meros.liveConnect(chain.last())
  rpc.meros.syncConnect(chain.last())

  #Send a blank block so Meros acknowledges a holder.
  sentHeader: bytes = rpc.meros.liveBlockHeader(blank.header)
  rpc.meros.handleBlockBody(blank)
  if rpc.meros.live.recv() != sentHeader:
    raise TestError("Meros didn't rebroadcast the header for a blank Block.")

  rpc.meros.liveBlockHeader(block.header)
  rpc.meros.handleBlockBody(block)

  msg: bytes = rpc.meros.sync.recv()
  if MessageType(msg[0]) != MessageType.SketchHashRequests:
    raise TestError("Unexpected message sent: " + msg.hex().upper())
  if msg[1 : 33] != block.header.hash:
    raise TestError("Meros asked for Verification Packets that didn't belong to the Block we just sent it.")
  if int.from_bytes(msg[33 : 37], byteorder="little") != 1:
    raise TestError("Meros didn't ask for one VerificationPacket.")
  if int.from_bytes(msg[37 : 45], byteorder="little") != Sketch.hash(block.header.sketchSalt, block.body.packets[0]):
    raise TestError("Meros didn't ask for the VerificationPacket.")
  rpc.meros.packet(block.body.packets[0])

  #Try receiving from the Live socket, where Meros sends keep-alives.
  try:
    if len(rpc.meros.live.recv()) != 0:
      raise Exception()
  except TestError:
    #Verify the node didn't crash.
    sleep(1)
    if rpc.meros.process.poll() is not None:
      raise TestError("Node crashed trying to handle a VerificationPacket with no holders.")
  except Exception:
    raise TestError("Meros didn't disconnect us after sending a VerificationPacket with no holders; it also didn't crash.")
