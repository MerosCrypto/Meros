#Types.
from typing import Dict, Set, List, Tuple, Any

#Transactions classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Send import Send
from PythonTests.Classes.Transactions.Data import Data

#Consensus classes.
from PythonTests.Classes.Consensus.Element import SignedElement
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket
from PythonTests.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from PythonTests.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from PythonTests.Classes.Consensus.MeritRemoval import PartialMeritRemoval

#Merit classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.Block import Block

#NodeError and TestError Exceptions.
from PythonTests.Tests.Errors import NodeError, TestError

#Enum class.
from enum import Enum

#Subprocess class.
from subprocess import Popen

#Socket standard lib.
import socket

#Message Types.
class MessageType(
  Enum
):
  Handshake         = 0
  Syncing           = 1
  Busy            = 2
  BlockchainTail      = 3

  PeersRequest        = 4
  Peers           = 5
  BlockListRequest      = 6
  BlockList         = 7

  BlockHeaderRequest    = 9
  BlockBodyRequest      = 10
  SketchHashesRequest     = 11
  SketchHashRequests    = 12
  TransactionRequest    = 13
  DataMissing         = 14

  Claim           = 15
  Send            = 16
  Data            = 17

  SignedVerification    = 20
  SignedSendDifficulty    = 21
  SignedDataDifficulty    = 22
  SignedMeritRemoval    = 24

  BlockHeader         = 26
  BlockBody         = 27
  SketchHashes        = 28
  VerificationPacket    = 29

  #MessageType -> byte.
  def toByte(
    self
  ) -> bytes:
    #This is totally redundant. It shouldn't exist.
    #That said, it isn't redundant, as Mypy errors without it.
    result: bytes = self.value.to_bytes(1, "big")
    return result

#Lengths of messages.
#An empty array means the message was just the header.
#A positive number means read X bytes.
#A negative number means read the last length * X bytes.
#A zero means custom logic should be used.
live_lengths: Dict[MessageType, List[int]] = {
  MessageType.Handshake:      [37],
  MessageType.Busy:         [1, -6],
  MessageType.BlockchainTail:     [32],

  MessageType.Claim:        [1, -33, 80],
  MessageType.Send:         [1, -33, 1, -40, 68],
  MessageType.Data:         [32, 1, -1, 69],

  MessageType.SignedVerification:   [82],
  MessageType.SignedSendDifficulty: [58],
  MessageType.SignedDataDifficulty: [58],
  MessageType.SignedMeritRemoval:   [4, 0, 1, 0, 48],

  MessageType.BlockHeader:      [107, 0, 56]
}

sync_lengths: Dict[MessageType, List[int]] = {
  MessageType.Syncing:       live_lengths[MessageType.Handshake],
  MessageType.Busy:        live_lengths[MessageType.Busy],
  MessageType.BlockchainTail:    [32],

  MessageType.PeersRequest:    [],
  MessageType.Peers:         live_lengths[MessageType.Busy],
  MessageType.BlockListRequest:  [34],
  MessageType.BlockList:       [1, -32, 32],

  MessageType.BlockHeaderRequest:  [32],
  MessageType.BlockBodyRequest:  [32],
  MessageType.SketchHashesRequest: [32],
  MessageType.SketchHashRequests:  [32, 4, -8],
  MessageType.TransactionRequest:  [32],
  MessageType.DataMissing:     [],

  MessageType.Claim:         live_lengths[MessageType.Claim],
  MessageType.Send:        live_lengths[MessageType.Send],
  MessageType.Data:        live_lengths[MessageType.Data],

  MessageType.BlockHeader:     live_lengths[MessageType.BlockHeader],
  MessageType.BlockBody:       [32, 4, -8, 4, 0, 48],
  MessageType.SketchHashes:    [4, -8],
  MessageType.VerificationPacket:  [2, -2, 32]
}

#Receive a message.
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
        byteorder="big"
      ) * abs(length)
    elif length == 0:
      if header == MessageType.SignedMeritRemoval:
        if result[-1] == 0:
          length = 32
        elif result[-1] == 1:
          result += socketRecv(connection, 2)
          length = (int.from_bytes(result[-2:], byteorder="big") * 96) + 32
        elif result[-1] == 2:
          length = 8
        elif result[-1] == 3:
          length = 8
        else:
          raise Exception("Meros sent an Element we don't recognize.")

      elif header == MessageType.BlockHeader:
        if result[-1] == 1:
          length = 96
        else:
          length = 2

      elif header == MessageType.BlockBody:
        elementsLen: int = int.from_bytes(result[-4:], byteorder="big")
        for _ in range(elementsLen):
          result += socketRecv(connection, 1)
          if result[-1] == 2:
            result += socketRecv(connection, 10)
          elif result[-1] == 3:
            result += socketRecv(connection, 10)
          elif result[-1] == 4:
            result += socketRecv(connection, 10)
          elif result[-1] == 5:
            result += socketRecv(connection, 4)
            for e in range(2):
              if result[-1] == 0:
                result += socketRecv(connection, 32)
              elif result[-1] == 1:
                result += socketRecv(connection, 2)
                result += socketRecv(connection, (int.from_bytes(result[-2:], byteorder="big") * 96) + 32)
              elif result[-1] == 2:
                result += socketRecv(connection, 8)
              elif result[-1] == 3:
                result += socketRecv(connection, 8)
              elif result[-1] == 4:
                result += socketRecv(connection, 8)
              if e == 0:
                result += socketRecv(connection, 1)
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
  #Constructor.
  def __init__(
    self,
    tcp: int,
    network: int,
    protocol: int,
    live: bool,
    tail: bytes
  ) -> None:
    #Save the connection type.
    self.live: bool = live

    #Create the connection and connect.
    self.connection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self.connection.connect(("127.0.0.1", tcp))

    #Send our Handshake.
    self.connection.send(
      (MessageType.Handshake.toByte() if live else MessageType.Syncing.toByte()) +
      network.to_bytes(1, "big") +
      protocol.to_bytes(1, "big") +
      b'\0\0\0' +
      tail
    )

    #Receive their Handshake.
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
    if response[1] != network:
      raise TestError("Connected to a node on a diffirent network.")
    if response[2] != protocol:
      raise TestError("Connected to a node using a diffirent protocol.")

    #Declare lists for the messages.
    self.msgs: List[bytes] = []
    self.ress: List[bytes] = []

  #Send a message.
  def send(
    self,
    msg: bytes,
    save: bool = True
  ) -> None:
    self.ress.append(msg)
    self.connection.send(msg)

  #Receive a message.
  def recv(
    self,
    save: bool = True
  ) -> bytes:
    result: bytes = recv(self.connection, live_lengths if self.live else sync_lengths)
    self.msgs.append(result)
    return result

  #Playback the connection's messages.
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
  #Constructor.
  def __init__(
    self,
    test: str,
    tcp: int,
    rpc: int
  ) -> None:
    #Save the network/protocol.
    self.network = 254
    self.protocol = 254

    #Save the config.
    self.db: str = test
    self.tcp: int = tcp
    self.rpc: int = rpc

    #Create the instance.
    self.process: Popen[Any] = Popen(["./build/Meros", "--data-dir", "./data/PythonTests", "--log-file", test + ".log", "--db", test, "--network", "devnet", "--tcp-port", str(tcp), "--rpc-port", str(rpc), "--no-gui"])

    #Connection variables.
    self.live: MerosSocket
    self.sync: MerosSocket

    #Transactions we've sent.
    self.sentTXs: Set[bytes] = set({})

  #Connect to Meros and Handshake with it.
  def syncConnect(
    self,
    tail: bytes
  ) -> None:
    self.sync = MerosSocket(self.tcp, self.network, self.protocol, False, tail)

  def liveConnect(
    self,
    tail: bytes
  ) -> None:
    self.live = MerosSocket(self.tcp, self.network, self.protocol, True, tail)

  #Send a peers request.
  def peersRequest(
    self
  ) -> bytes:
    res: bytes = MessageType.PeersRequest.toByte()
    self.sync.send(res, False)
    return res

  #Send peers.
  def peers(
    self,
    peers: List[Tuple[str, int]]
  ) -> bytes:
    res: bytes = MessageType.Peers.toByte()
    for peer in peers:
      ipParts: List[str] = peer[0].split(".")
      res += (
        int(ipParts[0]).to_bytes(1, byteorder="big") +
        int(ipParts[1]).to_bytes(1, byteorder="big") +
        int(ipParts[2]).to_bytes(1, byteorder="big") +
        int(ipParts[3]).to_bytes(1, byteorder="big") +
        peer[1].to_bytes(2, byteorder="big")
      )
    self.sync.send(res, False)
    return res

  #Send a Block List.
  def blockList(
    self,
    hashes: List[bytes]
  ) -> bytes:
    res: bytes = (
      MessageType.BlockList.toByte() +
      (len(hashes) - 1).to_bytes(1, byteorder="big")
    )
    for blockHash in hashes:
      res += blockHash
    self.sync.send(res)
    return res

  #Send a Data Missing.
  def dataMissing(
    self
  ) -> bytes:
    res: bytes = MessageType.DataMissing.toByte()
    self.sync.send(res)
    return res

  #Send a Transaction over the Sync socket.
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

  #Send a Transaction over the Live socket.
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

  #Send a Signed Element.
  def signedElement(
    self,
    elem: SignedElement,
    lookup: List[bytes] = []
  ) -> bytes:
    res: bytes = bytes()
    if isinstance(elem, SignedVerification):
      res = MessageType.SignedVerification.toByte()
    elif isinstance(elem, SignedDataDifficulty):
      res = MessageType.SignedDataDifficulty.toByte()
    elif isinstance(elem, SignedSendDifficulty):
      res = MessageType.SignedSendDifficulty.toByte()
    elif isinstance(elem, PartialMeritRemoval):
      res = MessageType.SignedMeritRemoval.toByte()
    else:
      raise Exception("Unsupported Element passed to Meros.signedElement.")
    res += elem.signedSerialize()

    self.live.send(res)
    return res

  #Send a Block Header.
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

  #Send a Block Header.
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

  #Send a Block Body.
  def blockBody(
    self,
    block: Block
  ) -> bytes:
    res: bytes = (
      MessageType.BlockBody.toByte() +
      block.body.serialize(block.header.sketchSalt)
    )
    self.sync.send(res)
    return res

  #Send sketch hashes.
  def sketchHashes(
    self,
    hashes: List[int]
  ) -> bytes:
    res: bytes = MessageType.SketchHashes.toByte() + len(hashes).to_bytes(4, byteorder="big")
    for sketchHash in hashes:
      res += sketchHash.to_bytes(8, byteorder="big")
    self.sync.send(res)
    return res

  #Send a Verification Packet.
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

  #Check the return code.
  def quit(
    self
  ) -> None:
    while self.process.poll() == None:
      pass

    if self.process.returncode != 0:
      raise NodeError("Meros didn't quit with code 0.")
