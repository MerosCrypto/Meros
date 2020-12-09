from typing import Dict, Any
import socket

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

from e2e.Tests.Errors import TestError

def TwoHundredFourtyTest(
  rpc: RPC
) -> None:
  #Grab the keys.
  blsPrivKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMiner")))
  blsPubKey: PublicKey = blsPrivKey.toPublicKey()

  #Blockchain used to calculate the difficulty.
  blockchain: Blockchain = Blockchain()

  #Mine enough blocks to lose Merit.
  for b in range(9):
    template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", [blsPubKey.serialize().hex()])
    template["header"] = bytes.fromhex(template["header"])

    header: BlockHeader = BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      0,
      blockchain.blocks[-1].header.time + 1200
    )
    if b == 0:
      header.newMiner = True
      header.minerKey = blsPubKey.serialize()
    header.mine(blsPrivKey, blockchain.difficulty())
    blockchain.add(Block(header, BlockBody()))

  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)
  for b in range(1, 10):
    headerMsg: bytes = rpc.meros.liveBlockHeader(blockchain.blocks[b].header)
    if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockBodyRequest:
      raise TestError("Meros didn't request the Block Body.")
    rpc.meros.blockBody(blockchain.blocks[b])
    if rpc.meros.live.recv() != headerMsg:
      raise TestError("Meros didn't broadcast back the Block Header.")
    if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
      raise TestError("Meros didn't sign a verification of the Block's data.")

  try:
    rpc.meros.live.connection.shutdown(socket.SHUT_RDWR)
    rpc.meros.live.connection.close()
    rpc.meros.sync.connection.shutdown(socket.SHUT_RDWR)
    rpc.meros.sync.connection.close()
  except OSError:
    pass

  #Verify our Merit is locked.
  if rpc.call("merit", "getMerit", [0])["status"] != "Locked":
    raise Exception("Our Merit isn't locked so this test is invalid.")

  template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", [blsPubKey.serialize().hex()])
  template["header"] = bytes.fromhex(template["header"])

  header: BlockHeader = BlockHeader(
    0,
    template["header"][4 : 36],
    template["header"][36 : 68],
    int.from_bytes(template["header"][68 : 70], byteorder="little"),
    template["header"][70 : 74],
    template["header"][74 : 106],
    0,
    int.from_bytes(template["header"][-4:], byteorder="little")
  )
  if not any(header.contents):
    raise TestError("Meros didn't try to unlock its Merit.")
  header.mine(blsPrivKey, blockchain.difficulty())
  #Don't add the last block because we never provided it with a proper body.

  rpc.call(
    "merit",
    "publishBlock",
    [
      template["id"],
      (
        template["header"] +
        header.proof.to_bytes(4, byteorder="little") +
        header.signature
      ).hex()
    ]
  )

  #To verify the entire chain, we just need to verify this last header.
  #This is essential as our chain isn't equivalent.
  if rpc.call("merit", "getBlock", [header.hash.hex()])["header"] != header.toJSON():
    raise TestError("Header wasn't added to the blockchain.")
