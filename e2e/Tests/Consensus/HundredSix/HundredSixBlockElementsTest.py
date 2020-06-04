#https://github.com/MerosCrypto/Meros/issues/106. Specifically tests elements in Blocks (except MeritRemovals).

#Types.
from typing import Dict, List, IO, Any

#Sketch class.
from e2e.Libs.Minisketch import Sketch

#Blockchain classes.
from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#VerificationPacket class.
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

#Transactions class.
from e2e.Classes.Transactions.Transactions import Transactions

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

#TestError Exception.
from e2e.Tests.Errors import TestError

#Sleep standard function.
from time import sleep

#JSON standard lib.
import json

#pylint: disable=too-many-statements
def HundredSixBlockElementsTest(
  rpc: RPC
) -> None:
  #Load the vectors.
  file: IO[Any] = open("e2e/Vectors/Consensus/HundredSix/BlockElements.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #Blockchain. Solely used to get the genesis Block hash.
  blockchain: Blockchain = Blockchain()

  #Transactions.
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #Parse the Blocks from the vectors.
  blocks: List[Block] = []
  for block in vectors["blocks"]:
    blocks.append(Block.fromJSON(block))

  for block in blocks:
    #Handshake with the node.
    rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
    rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

    #Send the Block.
    rpc.meros.liveBlockHeader(block.header)

    #Flag of if the Block's Body synced.
    doneSyncing: bool = False

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
      if MessageType(msg[0]) == MessageType.BlockBodyRequest:
        reqHash = msg[1 : 33]
        if reqHash != block.header.hash:
          raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

        #Send the BlockBody.
        rpc.meros.blockBody(block)

        if len(block.body.packets) == 0:
          doneSyncing = True

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
        for h in range(int.from_bytes(msg[33 : 37], byteorder="big")):
          sketchHash: int = int.from_bytes(msg[37 + (h * 8) : 45 + (h * 8)], byteorder="big")
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

    #Reset the node.
    rpc.reset()
