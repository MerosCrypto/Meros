#Tests that blocks can't have multiple verification packets for the same transaction.
from typing import Dict, Any
import json

from pytest import raises

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError

def MultiplePacketsTest(
  rpc: RPC
) -> None:
  #Spawn a Blockchain just to set the RandomX key.
  _: Blockchain = Blockchain()

  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/MultiplePackets.json", "r") as file:
    vectors = json.loads(file.read())

  data: Data = Data.fromJSON(vectors["data"])
  block: Block = Block.fromJSON(vectors["blockchain"][-1])

  def sendDataAndBlock() -> None:
    #Send the Data.
    if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back the Data.")

    rpc.meros.liveBlockHeader(block.header)
    rpc.meros.handleBlockBody(block)
    msg: bytes = rpc.meros.sync.recv()
    if MessageType(msg[0]) != MessageType.SketchHashRequests:
      raise TestError("Meros didn't request the packets for this Block.")

    packets: Dict[int, VerificationPacket] = {}
    for packet in block.body.packets:
      packets[Sketch.hash(block.header.sketchSalt, packet)] = packet

    #Look up each requested packet and respond accordingly.
    for h in range(int.from_bytes(msg[33 : 37], byteorder="little")):
      sketchHash: int = int.from_bytes(msg[37 + (h * 8) : 45 + (h * 8)], byteorder="little")
      if sketchHash not in packets:
        raise TestError("Meros asked for a non-existent Sketch Hash.")
      rpc.meros.packet(packets[sketchHash])

    try:
      if MessageType(rpc.meros.live.recv()[0]) == MessageType.BlockHeader:
        raise TestError("Meros added the Block.")
    except Exception as e:
      if str(e) != "Meros added the Block.":
        raise SuccessError()

  with raises(SuccessError):
    Liver(
      rpc,
      vectors["blockchain"],
      callbacks={
        2: sendDataAndBlock
      }
    ).live()
