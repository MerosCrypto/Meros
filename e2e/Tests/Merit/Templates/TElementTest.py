from typing import Dict, List, IO, Any
from time import sleep
import json

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Merit.Blockchain import BlockHeader
from e2e.Classes.Merit.Blockchain import BlockBody
from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Merit import Merit

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError
from e2e.Tests.Merit.Verify import verifyBlockchain

#pylint: disable=too-many-locals,too-many-statements
def TElementTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/ChainAdvancement.json", "r")
  blocks: List[Dict[str, Any]] = json.loads(file.read())[0]
  file.close()
  merit: Merit = Merit()

  blsPrivKey: PrivateKey = PrivateKey(0)
  blsPubKey: str = blsPrivKey.toPublicKey().serialize().hex()

  #Handshake with the node.
  rpc.meros.liveConnect(merit.blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(merit.blockchain.blocks[0].header.hash)

  #Send the first Block.
  block: Block = Block.fromJSON(blocks[0])
  merit.blockchain.add(block)
  rpc.meros.liveBlockHeader(block.header)

  #Handle sync requests.
  reqHash: bytes = bytes()
  while True:
    msg: bytes = rpc.meros.sync.recv()
    if MessageType(msg[0]) == MessageType.BlockBodyRequest:
      reqHash = msg[1 : 33]
      if reqHash != block.header.hash:
        raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

      rpc.meros.blockBody(block)
      break

    else:
      raise TestError("Unexpected message sent: " + msg.hex().upper())

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
      1,
      template["header"][-43 : -39],
      BlockHeader.createSketchCheck(template["header"][-43 : -39], []),
      0,
      int.from_bytes(template["header"][-4:], byteorder="big"),
    ),
    BlockBody([], [dataDiff], dataDiff.signature)
  )
  if block.header.serializeHash()[:-4] != template["header"]:
    raise TestError("Failed to recreate the header.")
  if block.body.serialize(block.header.sketchSalt) != bytes.fromhex(template["body"]):
    raise TestError("Failed to recreate the body.")

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
        block.header.proof.to_bytes(4, byteorder="big") +
        block.header.signature +
        block.body.serialize(block.header.sketchSalt)
      ).hex()
    ]
  )

  #Create and transmit a new DataDifficulty.
  dataDiff = SignedDataDifficulty(3, 1, 0)
  dataDiff.sign(0, blsPrivKey)
  rpc.meros.signedElement(dataDiff)
  sleep(0.5)

  #Verify the block template has the DataDifficulty.
  template = rpc.call("merit", "getBlockTemplate", [blsPubKey])
  template["header"] = bytes.fromhex(template["header"])
  if template["header"][36 : 68] != BlockHeader.createContents([], [dataDiff]):
    raise TestError("Block template doesn't have the new Data Difficulty.")

  #Create and transmit a new DataDifficulty reusing an existing nonce.
  signatures: List[Signature] = [dataDiff.signature]
  dataDiff = SignedDataDifficulty(4, 1, 0)
  dataDiff.sign(0, blsPrivKey)
  signatures.append(dataDiff.signature)
  rpc.meros.signedElement(dataDiff)
  sleep(0.5)

  #Verify the block template has a MeritRemoval.
  mr: MeritRemoval = MeritRemoval(
    SignedDataDifficulty(3, 1, 0),
    SignedDataDifficulty(4, 1, 0),
    False
  )
  template = rpc.call("merit", "getBlockTemplate", [blsPubKey])
  template["header"] = bytes.fromhex(template["header"])
  if template["header"][36 : 68] != BlockHeader.createContents([], [mr]):
    raise TestError("Block template doesn't have the Merit Removal.")

  #Mine the Block.
  block = Block(
    BlockHeader(
      0,
      block.header.hash,
      BlockHeader.createContents([], [mr]),
      1,
      template["header"][-43 : -39],
      BlockHeader.createSketchCheck(template["header"][-43 : -39], []),
      0,
      int.from_bytes(template["header"][-4:], byteorder="big")
    ),
    BlockBody([], [mr], Signature.aggregate(signatures))
  )
  if block.header.serializeHash()[:-4] != template["header"]:
    raise TestError("Failed to recreate the header.")
  if block.body.serialize(block.header.sketchSalt) != bytes.fromhex(template["body"]):
    raise TestError("Failed to recreate the body.")

  block.mine(blsPrivKey, merit.blockchain.difficulty())
  merit.blockchain.add(block)

  rpc.call(
    "merit",
    "publishBlock",
    [
      template["id"],
      (
        template["header"] +
        block.header.proof.to_bytes(4, byteorder="big") +
        block.header.signature +
        block.body.serialize(block.header.sketchSalt)
      ).hex()
    ]
  )

  verifyBlockchain(rpc, merit.blockchain)
