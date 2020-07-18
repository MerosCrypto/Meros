from time import sleep
import socket

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType, Meros

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-statements
def LANPeersTest(
  meros: Meros
) -> None:
  #Solely used to get the genesis Block hash.
  blockchain: Blockchain = Blockchain()

  #Handshake with the node.
  meros.syncConnect(blockchain.blocks[0].header.hash)

  #Verify that sending a PeersRequest returns 0 peers.
  meros.peersRequest()
  if len(meros.sync.recv()) != 2:
    raise TestError("Meros sent peers.")

  #Create a new connection which identifies as a server.
  serverConnection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  serverConnection.connect(("127.0.0.1", meros.tcp))
  serverConnection.send(
    MessageType.Syncing.toByte() +
    (254).to_bytes(1, "little") +
    (254).to_bytes(1, "little") +
    (128).to_bytes(1, "little") + (6000).to_bytes(2, "little") +
    blockchain.blocks[0].header.hash,
    False
  )
  serverConnection.recv(38)
  sleep(1)

  #Verify Meros ignores us as a peer since we're only available over the local network.
  meros.peersRequest()
  res: bytes = meros.sync.recv()
  if len(res) != 2:
    raise TestError("Meros sent peers.")

  #Close the new connection.
  serverConnection.close()
