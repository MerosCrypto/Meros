#Types.
from typing import Dict, List, Set, Union, Any

#Sketch class.
from e2e.Libs.Minisketch import Sketch

#Merit classes.
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Merit

#Element classes.
from e2e.Classes.Consensus.Verification import Verification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

#Transactions class.
from e2e.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from e2e.Tests.Errors import TestError

#Meros classes.
from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

#Merit and Transactions verifiers.
from e2e.Tests.Merit.Verify import verifyBlockchain
from e2e.Tests.Transactions.Verify import verifyTransactions

#pylint: disable=too-many-instance-attributes,too-few-public-methods
class Syncer:
  def __init__(
    self,
    rpc: RPC,
    blockchain: List[Dict[str, Any]],
    transactions: Union[Transactions, None] = None,
    settings: Dict[str, Any] = {}
  ) -> None:
    #RPC.
    self.rpc: RPC = rpc

    #DBs/Settings.
    self.merit: Merit = Merit.fromJSON(blockchain)
    self.transactions: Union[Transactions, None] = transactions
    self.settings: Dict[str, Any] = dict(settings)

    #Provide default settings.
    if "height" not in self.settings:
      self.settings["height"] = len(self.merit.blockchain.blocks) - 1
    if "playback" not in self.settings:
      self.settings["playback"] = True

    #List of Block hashes in this Blockchain.
    self.blockHashes: Set[bytes] = set()
    for b in range(1, self.settings["height"] + 1):
      self.blockHashes.add(self.merit.blockchain.blocks[b].header.hash)

    #List of mentioned Blocks.
    self.blocks: List[Block] = [self.merit.blockchain.blocks[self.settings["height"]]]

    #Dict of mentioned packets.
    self.packets: Dict[int, VerificationPacket] = {}

    #Set of mentioned Transactions.
    self.txs: Set[bytes] = set()
    #Dict of synced Transactions.
    self.synced: Set[bytes] = set()

  #Sync the DB and verify it.
  #The following PyLint errors are due to handling all the various message types.
  #pylint: disable=too-many-nested-blocks,too-many-statements
  def sync(
    self
  ) -> None:
    #Handshake with the node.
    self.rpc.meros.syncConnect(self.merit.blockchain.blocks[self.settings["height"]].header.hash)

    #Handle sync requests.
    reqHash: bytes = bytes()
    while True:
      #Break out of the for loop if the sync finished.
      #This means we sent every Block, every Element, every Transaction...
      if (
        (self.blockHashes == set()) and
        (self.packets == {}) and
        (self.txs == set())
      ):
        break

      msg: bytes = self.rpc.meros.sync.recv()

      if MessageType(msg[0]) == MessageType.BlockListRequest:
        reqHash = msg[3 : 35]
        for b in range(len(self.merit.blockchain.blocks)):
          if self.merit.blockchain.blocks[b].header.hash == reqHash:
            blockList: List[bytes] = []
            for bl in range(1, msg[2] + 2):
              if msg[1] == 0:
                if b - bl < 0:
                  break

                blockList.append(self.merit.blockchain.blocks[b - bl].header.hash)
                if b - bl != 0:
                  self.blocks.append(self.merit.blockchain.blocks[b - bl])

              elif msg[1] == 1:
                if b + bl > self.settings["height"]:
                  break

                blockList.append(self.merit.blockchain.blocks[b + bl].header.hash)
                self.blocks.append(self.merit.blockchain.blocks[b + bl])

              else:
                raise TestError("Meros asked for an invalid direction in a BlockListRequest.")

            if blockList == []:
              self.rpc.meros.dataMissing()
              break

            self.rpc.meros.blockList(blockList)
            break

          if b == self.settings["height"]:
            self.rpc.meros.dataMissing()

      elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
        if (self.txs != set()) or (self.packets != {}):
          raise TestError("Meros asked for a new Block before syncing the last Block's Transactions and Packets.")

        reqHash = msg[1 : 33]
        if reqHash != self.blocks[-1].header.hash:
          raise TestError("Meros asked for a BlockHeader other than the next Block's on the last BlockList.")

        self.rpc.meros.syncBlockHeader(self.blocks[-1].header)

      elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
        reqHash = msg[1 : 33]
        if reqHash != self.blocks[-1].header.hash:
          raise TestError("Meros asked for a BlockBody other than the next Block's on the last BlockList.")

        self.rpc.meros.blockBody(self.blocks[-1])
        self.blockHashes.remove(self.blocks[-1].header.hash)

        #Set packets/transactions.
        self.packets = {}
        for packet in self.blocks[-1].body.packets:
          if packet.hash not in self.synced:
            self.txs.add(packet.hash)
          self.packets[Sketch.hash(self.blocks[-1].header.sketchSalt, packet)] = packet

        #Update the list of mentioned Transactions.
        noVCMRs: bool = True
        for elem in self.blocks[-1].body.elements:
          if isinstance(elem, MeritRemoval):
            if isinstance(elem.e1, (Verification, VerificationPacket)):
              self.txs.add(elem.e1.hash)
              noVCMRs = False
            if isinstance(elem.e2, (Verification, VerificationPacket)):
              self.txs.add(elem.e2.hash)
              noVCMRs = False

        if (self.packets == {}) and noVCMRs:
          del self.blocks[-1]

      elif MessageType(msg[0]) == MessageType.SketchHashesRequest:
        reqHash = msg[1 : 33]
        if reqHash != self.blocks[-1].header.hash:
          raise TestError("Meros asked for Sketch Hashes that didn't belong to the header we just sent it.")

        #Get the haashes.
        hashes: List[int] = list(self.packets)

        #Send the Sketch Hashes.
        self.rpc.meros.sketchHashes(hashes)

      elif MessageType(msg[0]) == MessageType.SketchHashRequests:
        if not self.packets:
          raise TestError("Meros asked for Verification Packets from a Block without any.")

        reqHash = msg[1 : 33]
        if reqHash != self.blocks[-1].header.hash:
          raise TestError("Meros asked for Verification Packets that didn't belong to the Block we just sent it.")

        #Look up each requested packet and respond accordingly.
        for h in range(int.from_bytes(msg[33 : 37], byteorder="big")):
          sketchHash: int = int.from_bytes(msg[37 + (h * 8) : 45 + (h * 8)], byteorder="big")
          if sketchHash not in self.packets:
            raise TestError("Meros asked for a non-existent Sketch Hash.")
          self.rpc.meros.packet(self.packets[sketchHash])
          del self.packets[sketchHash]

      elif MessageType(msg[0]) == MessageType.TransactionRequest:
        reqHash = msg[1 : 33]

        if self.transactions is None:
          raise TestError("Meros asked for a Transaction when we have none.")

        if reqHash not in self.transactions.txs:
          raise TestError("Meros asked for a Transaction we don't have.")

        if reqHash not in self.txs:
          raise TestError("Meros asked for a Transaction we haven't mentioned.")

        self.rpc.meros.syncTransaction(self.transactions.txs[reqHash])
        self.synced.add(reqHash)
        self.txs.remove(reqHash)

        if self.txs == set():
          del self.blocks[-1]

      else:
        raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Blockchain.
    verifyBlockchain(self.rpc, self.merit.blockchain)

    #Verify the Transactions.
    if self.transactions is not None:
      verifyTransactions(self.rpc, self.transactions)

    if self.settings["playback"]:
      #Playback their messages.
      self.rpc.meros.sync.playback()
