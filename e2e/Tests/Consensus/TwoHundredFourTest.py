from typing import Dict, Any
from time import sleep
import json

from pytest import raises

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

from e2e.Tests.Errors import TestError, SuccessError

def TwoHundredFourTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/TwoHundredFour.json", "r") as file:
    vectors = json.loads(file.read())

  #Instantiate a Blockchain to set the RandomX key.
  chain: Blockchain = Blockchain()
  blank: Block = Block.fromJSON(vectors["blank"])

  for blockJSON in vectors["blocks"]:
    block: Block = Block.fromJSON(blockJSON)

    rpc.meros.liveConnect(chain.last())
    rpc.meros.syncConnect(chain.last())

    #Send a blank block so Meros acknowledges a holder.
    sentHeader: bytes = rpc.meros.liveBlockHeader(blank.header)
    if rpc.meros.sync.recv() != MessageType.BlockBodyRequest.toByte() + blank.header.hash:
      raise TestError("Meros didn't request the body for a blank Block.")
    rpc.meros.blockBody(blank)
    if rpc.meros.live.recv() != sentHeader:
      raise TestError("Meros didn't rebroadcast the header for a blank Block.")

    with raises(SuccessError):
      rpc.meros.liveBlockHeader(block.header)
      sentProblem: bool = False
      while True:
        if sentProblem:
          #Try receiving from the Live socket, where Meros sends keep-alives.
          try:
            if len(rpc.meros.live.recv()) != 0:
              raise Exception()
          except TestError:
            #Verify the node didn't crash.
            sleep(1)
            if rpc.meros.process.poll() is not None:
              raise TestError("Node crashed trying to handle a VerificationPacket with no holders.")
            raise SuccessError("Node disconnected us after we sent a VerificationPacket with no holders.")
          except Exception:
            raise TestError("Meros didn't disconnect us after sending a VerificationPacket with no holders; it also didn't crash.")

        msg: bytes = rpc.meros.sync.recv()

        if MessageType(msg[0]) == MessageType.BlockBodyRequest:
          if msg[1 : 33] != block.header.hash:
            raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")
          rpc.meros.blockBody(block)

          #If this Block has no packets, we've already sent the problem.
          sentProblem = not block.body.packets

        elif MessageType(msg[0]) == MessageType.SketchHashRequests:
          if msg[1 : 33] != block.header.hash:
            raise TestError("Meros asked for Verification Packets that didn't belong to the Block we just sent it.")
          if int.from_bytes(msg[33 : 37], byteorder="little") != 1:
            raise TestError("Meros didn't ask for one VerificationPacket.")
          if int.from_bytes(msg[37 : 45], byteorder="little") != Sketch.hash(block.header.sketchSalt, block.body.packets[0]):
            raise TestError("Meros didn't ask for the VerificationPacket.")

          rpc.meros.packet(block.body.packets[0])
          sentProblem = True

        else:
          raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Reset the node for the next test case.
    rpc.reset()
