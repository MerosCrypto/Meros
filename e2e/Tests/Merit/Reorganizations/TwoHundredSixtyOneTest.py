from typing import Dict, Any
from time import sleep
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain
from e2e.Classes.Merit.Merit import Merit

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock

#pylint: disable=too-many-locals,too-many-statements
def TwoHundredSixtyOneTest(
  rpc: RPC
) -> None:
  merit: Merit = Merit()

  blsPrivKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMiner")))
  blsPubKey: str = blsPrivKey.toPublicKey().serialize().hex()

  #Get a template.
  template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", [blsPubKey])
  template["header"] = bytes.fromhex(template["header"])

  #Mine it.
  #Ignores the template except for the ID needed to publish it.
  #We could publish it over the socket to an identical effect, practically.
  #That said, this is more accurate to flow.
  block: Block = PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200, minerID=blsPrivKey).finish(0, merit)
  merit.add(block)

  #Connect in order to receive their Verification of the Block's Data.
  rpc.meros.liveConnect(merit.blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(merit.blockchain.blocks[0].header.hash)

  #Publish it.
  rpc.call("merit", "publishBlock", [template["id"], block.header.serialize().hex()])
  if MessageType(rpc.meros.live.recv()[0]) != MessageType.BlockHeader:
    raise TestError("Meros didn't broadcast a published Block.")

  #Receive their Verification.
  if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
    raise TestError("Meros didn't verify the Block's Data.")

  #Reorg past the chain with them as the nick.
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    blankBlocks: Blockchain = Blockchain.fromJSON(json.loads(file.read()))
    rpc.meros.liveBlockHeader(blankBlocks.blocks[2].header)

    if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockListRequest:
      raise TestError("Meros didn't request the Block List needed to reorg.")
    rpc.meros.blockList([blankBlocks.blocks[0].header.hash])

    if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockHeaderRequest:
      raise TestError("Meros didn't request the next Block Header on the list.")
    rpc.meros.syncBlockHeader(blankBlocks.blocks[1].header)

    for b in range(2):
      rpc.meros.handleBlockBody(blankBlocks.blocks[b+1])

  #Close the connection to give us time to mine Blocks without worrying about the handshake.
  rpc.meros.live.connection.close()
  rpc.meros.sync.connection.close()
  sleep(65)

  #Mine Blocks so we can re-org back to the original chain.
  merit.add(
    PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200, minerID=PrivateKey(1)).finish(0, merit)
  )
  merit.add(
    PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200, minerID=1).finish(0, merit)
  )

  #Reconnect.
  rpc.meros.liveConnect(merit.blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(merit.blockchain.blocks[0].header.hash)

  #Send the header for the original chain.
  rpc.meros.liveBlockHeader(merit.blockchain.blocks[3].header)

  if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockListRequest:
    raise TestError("Meros didn't request the Block List needed to reorg.")
  rpc.meros.blockList([merit.blockchain.blocks[1].header.hash, merit.blockchain.blocks[0].header.hash])

  for h in range(2):
    if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockHeaderRequest:
      raise TestError("Meros didn't request the next Block Header on the list.")
    rpc.meros.syncBlockHeader(merit.blockchain.blocks[h + 1].header)

  for b in range(3):
    rpc.meros.handleBlockBody(merit.blockchain.blocks[b + 1])

  if MessageType(rpc.meros.live.recv()[0]) != MessageType.BlockHeader:
    raise TestError("Meros didn't broadcast a Block it just synced.")

  if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
    raise TestError("Meros didn't verify the Block's Data after the re-org.")
