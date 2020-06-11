#Verifies Meros will send Busy when it starts approaching the open file limit.

from typing import List
from time import sleep
import socket

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType, BusyError, MerosSocket
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def ULimitTest(
  #Required so a Meros node is spawned.
  #pylint: disable=unused-argument
  rpc: RPC
) -> None:
  #Sleep 60 seconds so Meros can correct its FD count.
  sleep(60)

  #Solely used for the genesis Block hash.
  blockchain: Blockchain = Blockchain()

  #Create peers until Meros sends us busy.
  sockets: List[MerosSocket] = []
  while True:
    #Only create live sockets to trigger new peers for each socket.
    try:
      sockets.append(MerosSocket(5132, 254, 254, True, blockchain.blocks[0].header.hash))
    except BusyError as e:
      if e.handshake != (MessageType.Busy.toByte() + bytes(1)):
        raise TestError("Meros sent an invalid Busy message.")
      break

  #Trigger busy 32 more times to verify Meros doesn't still allocate file handles.
  for _ in range(32):
    try:
      MerosSocket(5132, 254, 254, True, blockchain.blocks[0].header.hash)
    except BusyError as e:
      if e.handshake != (MessageType.Busy.toByte() + bytes(1)):
        raise TestError("Meros sent an invalid Busy message.")
      continue
    raise TestError("Meros didn't send Busy despite being at capacity.")

  #Disconnect the last 50 sockets.
  for _ in range(50):
    sockets[-1].connection.shutdown(socket.SHUT_RDWR)
    sockets[-1].connection.close()
    del sockets[-1]

  #Send a Handshake over every remaining socket every 20 seconds for a minute.
  #Then Meros should update the amount of files it has open and accept 50 new sockets.
  for _ in range(3):
    for lSocket in sockets:
      lSocket.send(
        MessageType.Handshake.toByte() +
        (254).to_bytes(1, "big") +
        (254).to_bytes(1, "big") +
        b'\0\0\0' +
        blockchain.blocks[0].header.hash
      )
    sleep(20)

  #Connect 50 sockets and verify Meros doesn't think it's still at capacity.
  for _ in range(50):
    try:
      sockets.append(MerosSocket(5132, 254, 254, True, blockchain.blocks[0].header.hash))
    except BusyError:
      raise TestError("Meros thought it was at capcity when it wasn't.")

  #Verify connecting one more socket returns Busy.
  try:
    MerosSocket(5132, 254, 254, True, blockchain.blocks[0].header.hash)
  except BusyError:
    return
  raise TestError("Meros accepted a socket despite being at capcity.")
