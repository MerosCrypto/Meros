#https://github.com/MerosCrypto/Meros/issues/106. Specifically tests elements in Blocks (except MeritRemovals).

from typing import Dict, List, Any
from time import sleep
import json

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Blockchain import Blockchain
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-statements
def HundredSixBlockElementsTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/HundredSix/BlockElements.json", "r") as file:
    vectors = json.loads(file.read())

  #Solely used to get the genesis Block hash.
  blockchain: Blockchain = Blockchain()
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  blocks: List[Block] = []
  for block in vectors["blocks"]:
    blocks.append(Block.fromJSON(block))

  for block in blocks:
    #Handshake with the node.
    rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
    rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

    #Send the Block.
    rpc.meros.liveBlockHeader(block.header)
    rpc.meros.handleBlockBody(block)

    #Flag of if the Block's Body synced.
    doneSyncing: bool = len(block.body.packets) == 0

    #Handle sync requests.
    reqHash: bytes = bytes()
    while True:
      if doneSyncing:
        #Sleep for a second so Meros handles the Block.
        sleep(1)

        #Try receiving from the Live socket, where Meros sends keep-alives.
        try:
          if len(rpc.meros.live.recv()) != 0:
            raise Exception()
        except TestError:
          #Verify the node didn't crash.
          try:
            if rpc.call("merit", "getHeight") != 1:
              raise Exception()
          except Exception:
            raise TestError("Node crashed after being sent a malformed Element.")

          #Since the node didn't crash, break out of this loop to trigger the next test case.
          break
        except Exception:
          raise TestError("Meros sent a keep-alive.")

      msg: bytes = rpc.meros.sync.recv()
      if MessageType(msg[0]) == MessageType.SketchHashRequests:
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

        doneSyncing = True

      elif MessageType(msg[0]) == MessageType.TransactionRequest:
        reqHash = msg[1 : 33]

        if reqHash not in transactions.txs:
          raise TestError("Meros asked for a non-existent Transaction.")

        rpc.meros.syncTransaction(transactions.txs[reqHash])

      else:
        raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Reset the node so we can test the next invalid Block.
    rpc.reset()
