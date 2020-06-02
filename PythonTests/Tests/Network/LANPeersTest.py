#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Sleep standard function.
from time import sleep

#Socket standard lib.
import socket

#pylint: disable=too-many-statements
def LANPeersTest(
  rpc: RPC
) -> None:
  #Blockchain. Solely used to get the genesis Block hash.
  blockchain: Blockchain = Blockchain()

  #Handshake with the node.
  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

  #Verify that sending a PeersRequest returns 0 peers.
  rpc.meros.peersRequest()
  if len(rpc.meros.sync.recv()) != 2:
    raise TestError("Meros sent peers.")

  #Create a new connection which identifies as a server.
  serverConnection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  serverConnection.connect(("127.0.0.1", rpc.meros.tcp))
  serverConnection.send(
    MessageType.Syncing.toByte() +
    (254).to_bytes(1, "big") +
    (254).to_bytes(1, "big") +
    (128).to_bytes(1, "big") + (6000).to_bytes(2, "big") +
    blockchain.blocks[0].header.hash,
    False
  )
  serverConnection.recv(38)
  sleep(1)

  #Verify Meros ignores us as a peer since we're only available over the local network.
  rpc.meros.peersRequest()
  res: bytes = rpc.meros.sync.recv()
  if len(res) != 2:
    raise TestError("Meros sent peers.")

  #Close the new connection.
  serverConnection.close()
