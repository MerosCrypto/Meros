from typing import Dict, Any
from time import sleep
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Blockchain import BlockHeader
from e2e.Classes.Merit.Blockchain import BlockBody
from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Merit import Merit

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError
from e2e.Tests.Merit.Verify import verifyBlockchain

#pylint: disable=too-many-locals,too-many-statements
def TElementTest(
  rpc: RPC
) -> None:
  merit: Merit = Merit()

  blsPrivKey: PrivateKey = PrivateKey(0)
  blsPubKey: str = blsPrivKey.toPublicKey().serialize().hex()

  #Handshake with the node.
  rpc.meros.liveConnect(merit.blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(merit.blockchain.blocks[0].header.hash)

  #Send the first Block.
  block: Block
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    block = Block.fromJSON(json.loads(file.read())[0])
  merit.blockchain.add(block)
  rpc.meros.liveBlockHeader(block.header)
  rpc.meros.handleBlockBody(block)
  if MessageType(rpc.meros.live.recv()[0]) != MessageType.BlockHeader:
    raise TestError("Meros didn't broadcast the Block Header it just added.")

  #Create and transmit a DataDifficulty.
  dataDiff: SignedDataDifficulty = SignedDataDifficulty(0, 0, 0)
  dataDiff.sign(0, blsPrivKey)
  rpc.meros.signedElement(dataDiff)
  sleep(0.5)

  #Verify the block template has the DataDifficulty.
  template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", [blsPubKey])
  template["header"] = bytes.fromhex(template["header"])
  if template["header"][36 : 68] != BlockHeader.createContents([], [dataDiff]):
    raise TestError("Block template doesn't have the Data Difficulty.")

  #Mine the Block.
  block = Block(
    BlockHeader(
      0,
      block.header.hash,
      BlockHeader.createContents([], [dataDiff]),
      0,
      template["header"][-43 : -39],
      BlockHeader.createSketchCheck(template["header"][-43 : -39], []),
      0,
      int.from_bytes(template["header"][-4:], byteorder="little"),
    ),
    BlockBody([], [dataDiff], dataDiff.signature)
  )
  if block.header.serializeHash()[:-4] != template["header"]:
    raise TestError("Failed to recreate the header.")

  block.mine(blsPrivKey, merit.blockchain.difficulty())
  merit.blockchain.add(block)

  #Publish it.
  rpc.call(
    "merit",
    "publishBlock",
    [
      template["id"],
      (
        template["header"] +
        block.header.proof.to_bytes(4, byteorder="little") +
        block.header.signature
      ).hex()
    ]
  )

  #Create and transmit a new DataDifficulty.
  dataDiff = SignedDataDifficulty(3, 0, 0)
  dataDiff.sign(0, blsPrivKey)
  rpc.meros.signedElement(dataDiff)
  sleep(0.5)

  #Verify the block template has a MeritRemoval.
  #Thanks to implicit Merit Removals, this just means it has the new difficulty.
  template = rpc.call("merit", "getBlockTemplate", [blsPubKey])
  template["header"] = bytes.fromhex(template["header"])
  if template["header"][36 : 68] != BlockHeader.createContents([], [dataDiff]):
    raise TestError("Block template doesn't have the Merit Removal.")

  #Mine the Block.
  block = Block(
    BlockHeader(
      0,
      block.header.hash,
      BlockHeader.createContents([], [dataDiff]),
      0,
      template["header"][-43 : -39],
      BlockHeader.createSketchCheck(template["header"][-43 : -39], []),
      0,
      int.from_bytes(template["header"][-4:], byteorder="little")
    ),
    BlockBody([], [dataDiff], dataDiff.signature)
  )
  if block.header.serializeHash()[:-4] != template["header"]:
    raise TestError("Failed to recreate the header.")

  block.mine(blsPrivKey, merit.blockchain.difficulty())
  merit.blockchain.add(block)

  rpc.call(
    "merit",
    "publishBlock",
    [
      template["id"],
      (
        template["header"] +
        block.header.proof.to_bytes(4, byteorder="little") +
        block.header.signature
      ).hex()
    ]
  )

  verifyBlockchain(rpc, merit.blockchain)
