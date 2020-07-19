#Tests the proper handling of Sends which spend the same input twice.

from typing import Dict, List, IO, Any
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

#pylint: disable=too-many-statements
def SameInputTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Transactions/SameInput/Send.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  merit: Merit = Merit.fromJSON(vectors["blockchain"])
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #Custom function to send the last Block and verify it errors at the right place.
  def checkFail() -> None:
    #This Block should cause the node to disconnect us AFTER it syncs our Transaction.
    syncedTX: bool = False

    #Grab the Block.
    block: Block = merit.blockchain.blocks[9]

    #Send the Block.
    rpc.meros.liveBlockHeader(block.header)

    #Handle sync requests.
    reqHash: bytes = bytes()
    while True:
      if syncedTX:
        #Try receiving from the Live socket, where Meros sends keep-alives.
        try:
          if len(rpc.meros.live.recv()) != 0:
            raise Exception()
        except TestError:
          raise SuccessError("Node disconnected us after we sent an invalid Transaction.")
        except Exception:
          raise TestError("Meros sent a keep-alive.")

      msg: bytes = rpc.meros.sync.recv()
      if MessageType(msg[0]) == MessageType.BlockBodyRequest:
        reqHash = msg[1 : 33]
        if reqHash != block.header.hash:
          raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

        #Send the BlockBody.
        rpc.meros.blockBody(block)

      elif MessageType(msg[0]) == MessageType.SketchHashesRequest:
        if not block.body.packets:
          raise TestError("Meros asked for Sketch Hashes from a Block without any.")

        reqHash = msg[1 : 33]
        if reqHash != block.header.hash:
          raise TestError("Meros asked for Sketch Hashes that didn't belong to the Block we just sent it.")

        #Create the haashes.
        hashes: List[int] = []
        for packet in block.body.packets:
          hashes.append(Sketch.hash(block.header.sketchSalt, packet))

        #Send the Sketch Hashes.
        rpc.meros.sketchHashes(hashes)

      elif MessageType(msg[0]) == MessageType.SketchHashRequests:
        if not block.body.packets:
          raise TestError("Meros asked for Verification Packets from a Block without any.")

        reqHash = msg[1 : 33]
        if reqHash != block.header.hash:
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
        reqHash = msg[1 : 33]

        if reqHash not in transactions.txs:
          raise TestError("Meros asked for a non-existent Transaction.")

        rpc.meros.syncTransaction(transactions.txs[reqHash])
        syncedTX = True

      else:
        raise TestError("Unexpected message sent: " + msg.hex().upper())

  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, callbacks={8: checkFail}).live()
