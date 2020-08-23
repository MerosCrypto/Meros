import socket

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType, Meros

from e2e.Tests.Errors import TestError

def VarIntTest(
  meros: Meros
) -> None:
  #Solely used to get the genesis Block hash.
  blockchain: Blockchain = Blockchain()

  #Handshake with the node using a pointless VarInt for the protocol/network/services.
  live: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  live.connect(("127.0.0.1", meros.tcp))
  live.send(
    MessageType.Handshake.toByte() +
    int("1000000000000000", 2).to_bytes(2, "big") +
    int("11111111100000001000000000000000", 2).to_bytes(4, "big") +
    int("100000101001101000111010", 2).to_bytes(3, "big") +
    b'\0\0' +
    blockchain.blocks[0].header.hash
  )

  sync: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  sync.connect(("127.0.0.1", meros.tcp))
  sync.send(
    MessageType.Syncing.toByte() +
    int("1000000000000000", 2).to_bytes(2, "big") +
    int("11111111100000001000000000000000", 2).to_bytes(4, "big") +
    int("100000101001101000111010", 2).to_bytes(3, "big") +
    b'\0\0' +
    blockchain.blocks[0].header.hash
  )

  #Verify Meros considers us valid by receiving its initial handshake, and then waiting for the next one.
  if (
    (MessageType(live.recv(38)[0]) != MessageType.Handshake) or
    (MessageType(sync.recv(38)[0]) != MessageType.Syncing)
  ):
    raise TestError("Meros didn't handshake with us.")
  if MessageType(live.recv(38)[0]) != MessageType.Handshake:
    raise TestError("Meros didn't handshake with us to stop us from timing out.")
