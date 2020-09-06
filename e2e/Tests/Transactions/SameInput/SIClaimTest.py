from typing import Dict, Any
import json

from pytest import raises

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Merit
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError

def SameInputTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/SameInput/Claim.json", "r") as file:
    vectors = json.loads(file.read())

  merit: Merit = Merit.fromJSON(vectors["blockchain"])
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #Custom function to send the last Block and verify it errors at the right place.
  def checkFail() -> None:
    #Grab the Block.
    block: Block = merit.blockchain.blocks[8]

    #Send the Block.
    rpc.meros.liveBlockHeader(block.header)

    #Handle sync requests.
    while True:
      msg: bytes = rpc.meros.sync.recv()
      if MessageType(msg[0]) == MessageType.BlockBodyRequest:
        if msg[1 : 33] != block.header.hash:
          raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

        rpc.meros.blockBody(block)

      elif MessageType(msg[0]) == MessageType.SketchHashRequests:
        if msg[1 : 33] != block.header.hash:
          raise TestError("Meros asked for Verification Packets that didn't belong to the Block we just sent it.")

        #Create a lookup of hash to packets.
        packets: Dict[int, VerificationPacket] = {}
        for packet in block.body.packets:
          packets[Sketch.hash(block.header.sketchSalt, packet)] = packet

        #Look up each requested packet and respond accordingly.
        for h in range(int.from_bytes(msg[33 : 37], byteorder="little")):
          sketchHash: int = int.from_bytes(msg[37 + (h * 8) : 45 + (h * 8)], byteorder="little")
          if sketchHash not in packets:
            raise TestError("Meros asked for a non-existent Sketch Hash.")
          rpc.meros.packet(packets[sketchHash])

      elif MessageType(msg[0]) == MessageType.TransactionRequest:
        reqHash: bytes = msg[1 : 33]
        if reqHash not in transactions.txs:
          raise TestError("Meros asked for a non-existent Transaction.")

        rpc.meros.syncTransaction(transactions.txs[reqHash])

        #Try receiving from the Live socket, where Meros sends keep-alives.
        try:
          if len(rpc.meros.live.recv()) != 0:
            raise Exception()
        except TestError:
          raise SuccessError("Node disconnected us after we sent an invalid Transaction.")
        except Exception:
          raise TestError("Meros sent a keep-alive.")

      else:
        raise TestError("Unexpected message sent: " + msg.hex().upper())

  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, callbacks={7: checkFail}).live()
