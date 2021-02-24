from typing import Dict, Set, List, Tuple, Union, Any
from enum import Enum
from subprocess import Popen
from time import sleep
import socket

import requests

from e2e.Classes.Transactions.Transaction import Transaction
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Element import SignedElement
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import PartialMeritRemoval, SignedMeritRemoval

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.Block import Block

from e2e.Tests.Errors import NodeError, TestError

class MessageType(
  Enum
):
  Handshake      = 0
  Syncing        = 1
  Busy           = 2
  BlockchainTail = 3

  PeersRequest     = 4
  Peers            = 5
  BlockListRequest = 6
  BlockList        = 7

  BlockHeaderRequest  = 9
  BlockBodyRequest    = 10
  SketchHashesRequest = 11
  SketchHashRequests  = 12
  TransactionRequest  = 13
  DataMissing         = 14

  Claim = 15
  Send  = 16
  Data  = 17

  SignedVerification   = 20
  SignedSendDifficulty = 21
  SignedDataDifficulty = 22
  SignedMeritRemoval   = 24

  BlockHeader        = 26
  BlockBody          = 27
  SketchHashes       = 28
  VerificationPacket = 29

  def toByte(
    self
  ) -> bytes:
    return self.value.to_bytes(1, "little")

#Lengths of messages.
#An empty array means the message was just the header.
#A positive number means read X bytes.
#A negative number means read the last length * X bytes.
#A zero means custom logic should be used.
live_lengths: Dict[MessageType, List[int]] = {
  MessageType.Handshake:      [0, 0, 0, 2, 32],
  MessageType.Busy:           [1, -6],
  MessageType.BlockchainTail: [32],

  MessageType.Claim: [1, -33, 80],
  MessageType.Send:  [1, -33, 1, -40, 68],
  MessageType.Data:  [32, 1, -1, 69],

  MessageType.SignedVerification:   [82],
  MessageType.SignedSendDifficulty: [56],
  MessageType.SignedDataDifficulty: [56],
  MessageType.SignedMeritRemoval:   [4, 0, 1, 0, 48],

  MessageType.BlockHeader: [109, 0, 56]
}

sync_lengths: Dict[MessageType, List[int]] = {
  MessageType.Syncing:        live_lengths[MessageType.Handshake],
  MessageType.Busy:           live_lengths[MessageType.Busy],
  MessageType.BlockchainTail: [32],

  MessageType.PeersRequest:     [],
  MessageType.Peers:            live_lengths[MessageType.Busy],
  MessageType.BlockListRequest: [33],
  MessageType.BlockList:        [1, -32, 32],

  MessageType.BlockHeaderRequest:  [32],
  MessageType.BlockBodyRequest:    [36],
  MessageType.SketchHashesRequest: [32],
  MessageType.SketchHashRequests:  [32, 4, -8],
  MessageType.TransactionRequest:  [32],
  MessageType.DataMissing:         [],

  MessageType.Claim: live_lengths[MessageType.Claim],
  MessageType.Send:  live_lengths[MessageType.Send],
  MessageType.Data:  live_lengths[MessageType.Data],

  MessageType.BlockHeader:        live_lengths[MessageType.BlockHeader],
  MessageType.BlockBody:          [32, 4, -8, 4, 0, 48],
  MessageType.SketchHashes:       [4, -8],
  MessageType.VerificationPacket: [2, -2, 32]
}

#Receive a specified length from the socket, handling the errors.
def socketRecv(
  connection: socket.socket,
  length: int
) -> bytes:
  try:
    result: bytes = connection.recv(length)
    if len(result) != length:
      raise TestError()
    return result
  except Exception:
    raise TestError("Meros disconnected us.")

#Receive a message from this socket.
def recv(
  connection: socket.socket,
  lengths: Dict[MessageType, List[int]]
) -> bytes:
  #Receive the header.
  result: bytes = socketRecv(connection, 1)
  header: MessageType = MessageType(result[0])

  #Get the rest of the message.
  length: int
  for l in range(len(lengths[header])):
    length = lengths[header][l]
    if length < 0:
      length = int.from_bytes(
        result[-lengths[header][l - 1]:],
        byteorder="little"
      ) * abs(length)
    elif length == 0:
      if header in {MessageType.Handshake, MessageType.Syncing}:
        last: int = 1 << 7
        while (last >> 7) == 1:
          result += socketRecv(connection, 1)
          last = result[-1]
      elif header == MessageType.SignedMeritRemoval:
        if result[-1] == 0:
          length = 32
        elif result[-1] == 2:
          length = 6
        elif result[-1] == 3:
          length = 6
        else:
          raise Exception("Meros sent an Element we don't recognize.")

      elif header == MessageType.BlockHeader:
        if result[-1] == 1:
          length = 96
        else:
          length = 2

      elif header == MessageType.BlockBody:
        elementsLen: int = int.from_bytes(result[-4:], byteorder="little")
        for _ in range(elementsLen):
          result += socketRecv(connection, 1)
          if result[-1] == 2:
            result += socketRecv(connection, 8)
          elif result[-1] == 3:
            result += socketRecv(connection, 8)
          else:
            raise Exception("Block Body has an unknown element.")

    result += socketRecv(connection, length)

  return result

#Raised when the node is busy.
#This isn't defined in Errors because it has no relation to the test suite.
class BusyError(
  Exception
):
  def __init__(
    self,
    msg: str,
    handshake: bytes
  ) -> None:
    Exception.__init__(self, msg)
    self.handshake: bytes = handshake

class MerosSocket:
  def __init__(
    self,
    tcp: int,
    protocol: int,
    network: int,
    live: bool,
    tail: bytes
  ) -> None:
    self.live: bool = live

    self.connection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self.connection.connect(("127.0.0.1", tcp))
    self.connection.send(
      (MessageType.Handshake.toByte() if live else MessageType.Syncing.toByte()) +
      protocol.to_bytes(1, "little") +
      network.to_bytes(1, "little") +
      b'\0\0\0' +
      tail
    )

    response: bytes = recv(self.connection, live_lengths if live else sync_lengths)
    if MessageType(response[0]) == MessageType.Busy:
      #Wrapped in a try/except as this will error out if Meros beats it to the punch.
      try:
        self.connection.shutdown(socket.SHUT_RDWR)
        self.connection.close()
      except OSError:
        pass
      raise BusyError("Node was busy.", response)
    if MessageType(response[0]) != (MessageType.Handshake if live else MessageType.Syncing):
      raise TestError("Node didn't send the right Handshake for this connection type.")
    elif response[1] != protocol:
      raise Exception("Connected to a node on a diffirent network.")
    elif response[2] != network:
      raise Exception("Connected to a node using a diffirent protocol.")

    #Declare lists for the messages.
    self.msgs: List[bytes] = []
    self.ress: List[bytes] = []

  def send(
    self,
    msg: bytes
  ) -> None:
    self.ress.append(msg)
    self.connection.send(msg)

  def recv(
    self,
    allowPeersRequest: bool = False
  ) -> bytes:
    result: bytes = recv(self.connection, live_lengths if self.live else sync_lengths)
    while (not allowPeersRequest) and (MessageType(result[0]) == MessageType.PeersRequest):
      self.send(MessageType.Peers.toByte() + bytes(1))
      self.ress.pop()
      result = recv(self.connection, live_lengths if self.live else sync_lengths)
    self.msgs.append(result)
    return result

  #Playback the connection's messages.
  #Used to verify Meros can send as it receives.
  def playback(
    self
  ) -> None:
    if self.live:
      raise Exception("Attempted to playback a Live connection.")

    for m in range(len(self.msgs)):
      self.send(self.msgs[m])
      if self.recv() != self.ress[m]:
        raise TestError("Meros responded with a message different than expected.")

class Meros:
  def __init__(
    self,
    test: str,
    tcp: int,
    rpc: int,
    dataDir: str = "./data/e2e"
  ) -> None:
    self.protocol = 0
    self.network = 127

    self.dataDir: str = dataDir
    self.db: str = test
    self.log: str = test + ".log"
    self.tcp: int = tcp
    self.rpc: int = rpc

    self.calledQuit: bool = False
    self.process: Popen[Any] = Popen(["./build/Meros", "--data-dir", dataDir, "--log-file", self.log, "--db", self.db, "--network", "devnet", "--tcp-port", str(tcp), "--rpc-port", str(rpc), "--no-gui"])
    while True:
      try:
        connection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        connection.connect(("127.0.0.1", self.rpc))
        connection.shutdown(socket.SHUT_RDWR)
        connection.close()
        break
      except ConnectionRefusedError:
        sleep(1)

    self.live: MerosSocket
    self.sync: MerosSocket

    #Used by the Liver/Syncer when tests send outside of its normal flow.
    self.sentTXs: Set[bytes] = set({})
    self.sentVerifs: Dict[bytes, Set[int]] = {}

  def syncConnect(
    self,
    tail: bytes
  ) -> None:
    self.sync = MerosSocket(self.tcp, self.protocol, self.network, False, tail)

  def liveConnect(
    self,
    tail: bytes
  ) -> None:
    self.live = MerosSocket(self.tcp, self.protocol, self.network, True, tail)

  def peersRequest(
    self
  ) -> bytes:
    res: bytes = MessageType.PeersRequest.toByte()
    self.sync.send(res)
    self.sync.ress.pop()
    return res

  def peers(
    self,
    peers: List[Tuple[str, int]]
  ) -> bytes:
    res: bytes = MessageType.Peers.toByte() + len(peers).to_bytes(1, byteorder="little")
    for peer in peers:
      ipParts: List[str] = peer[0].split(".")
      res += (
        int(ipParts[0]).to_bytes(1, byteorder="little") +
        int(ipParts[1]).to_bytes(1, byteorder="little") +
        int(ipParts[2]).to_bytes(1, byteorder="little") +
        int(ipParts[3]).to_bytes(1, byteorder="little") +
        peer[1].to_bytes(2, byteorder="little")
      )
    self.sync.send(res)
    self.sync.ress.pop()
    return res

  def blockList(
    self,
    hashes: List[bytes]
  ) -> bytes:
    res: bytes = (
      MessageType.BlockList.toByte() +
      (len(hashes) - 1).to_bytes(1, byteorder="little")
    )
    for blockHash in hashes:
      res += blockHash
    self.sync.send(res)
    return res

  def dataMissing(
    self
  ) -> bytes:
    res: bytes = MessageType.DataMissing.toByte()
    self.sync.send(res)
    return res

  def syncTransaction(
    self,
    tx: Transaction
  ) -> bytes:
    self.sentTXs.add(tx.hash)

    res: bytes = bytes()
    if isinstance(tx, Claim):
      res = MessageType.Claim.toByte()
    elif isinstance(tx, Send):
      res = MessageType.Send.toByte()
    elif isinstance(tx, Data):
      res = MessageType.Data.toByte()
    res += tx.serialize()

    self.sync.send(res)
    return res

  def liveTransaction(
    self,
    tx: Transaction
  ) -> bytes:
    self.sentTXs.add(tx.hash)

    res: bytes = bytes()
    if isinstance(tx, Claim):
      res = MessageType.Claim.toByte()
    elif isinstance(tx, Send):
      res = MessageType.Send.toByte()
    elif isinstance(tx, Data):
      res = MessageType.Data.toByte()
    res += tx.serialize()

    self.live.send(res)
    return res

  def signedElement(
    self,
    elem: SignedElement
  ) -> bytes:
    res: bytes = bytes()
    if isinstance(elem, SignedVerification):
      if elem.hash not in self.sentVerifs:
        self.sentVerifs[elem.hash] = set([elem.holder])
      else:
        self.sentVerifs[elem.hash].add(elem.holder)
      res = MessageType.SignedVerification.toByte()
    elif isinstance(elem, SignedDataDifficulty):
      res = MessageType.SignedDataDifficulty.toByte()
    elif isinstance(elem, SignedSendDifficulty):
      res = MessageType.SignedSendDifficulty.toByte()
    else:
      raise Exception("Unsupported Element passed to Meros.signedElement.")
    res += elem.signedSerialize()

    self.live.send(res)
    return res

  def meritRemoval(
    self,
    mr: Union[PartialMeritRemoval, SignedMeritRemoval]
  ) -> bytes:
    res: bytes = MessageType.SignedMeritRemoval.toByte() + mr.serialize()
    self.live.send(res)
    return res

  def liveBlockHeader(
    self,
    header: BlockHeader
  ) -> bytes:
    res: bytes = (
      MessageType.BlockHeader.toByte() +
      header.serialize()
    )
    self.live.send(res)
    return res

  def syncBlockHeader(
    self,
    header: BlockHeader
  ) -> bytes:
    res: bytes = (
      MessageType.BlockHeader.toByte() +
      header.serialize()
    )
    self.sync.send(res)
    return res

  def rawBlockBody(
    self,
    block: Block,
    capacity: int
  ) -> None:
    self.sync.send(
      MessageType.BlockBody.toByte() +
      block.body.serialize(
        block.header.sketchSalt,
        capacity
      )
    )

  def handleBlockBody(
    self,
    block: Block,
    capacityOverride: int = -1
  ) -> None:
    msg: bytes = self.sync.recv()
    if MessageType(msg[0]) != MessageType.BlockBodyRequest:
      raise TestError("Meros didn't request a Block Body.")

    blockHash: bytes = msg[1 : 33]
    if blockHash != block.header.hash:
      raise TestError("Meros requested a different Block Body.")

    self.rawBlockBody(
      block,
      int.from_bytes(msg[33 : 37], byteorder="little") if capacityOverride == -1 else capacityOverride
    )

  def sketchHashes(
    self,
    hashes: List[int]
  ) -> bytes:
    res: bytes = MessageType.SketchHashes.toByte() + len(hashes).to_bytes(4, byteorder="little")
    for sketchHash in hashes:
      res += sketchHash.to_bytes(8, byteorder="little")
    self.sync.send(res)
    return res

  def packet(
    self,
    packet: VerificationPacket
  ) -> bytes:
    res: bytes = (
      MessageType.VerificationPacket.toByte() +
      packet.serialize()
    )
    self.sync.send(res)
    return res

  #Quit, checking the return code.
  def quit(
    self
  ) -> None:
    if not self.calledQuit:
      requests.post("http://127.0.0.1:" + str(self.rpc), json={
        "jsonrpc": "2.0",
        "id": 0,
        "method": "system_quit"
      })
      self.calledQuit = True

    while self.process.poll() is None:
      pass

    if self.process.returncode != 0:
      raise NodeError("Meros didn't quit with code 0.")
