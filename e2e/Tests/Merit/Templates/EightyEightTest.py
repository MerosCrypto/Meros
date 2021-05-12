#https://github.com/MerosCrypto/Meros/issues/88

from typing import Dict, List, Any
from time import sleep
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Merit.Blockchain import BlockHeader
from e2e.Classes.Merit.Blockchain import BlockBody
from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Merit import Merit

from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Classes.Transactions.Data import Data

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError
from e2e.Tests.Merit.Verify import verifyBlockchain

#pylint: disable=too-many-locals,too-many-statements
def EightyEightTest(
  rpc: RPC
) -> None:
  edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
  edPubKey: bytes = edPrivKey.get_verifying_key()

  blsPrivKey: PrivateKey = PrivateKey(0)
  blsPubKey: str = blsPrivKey.toPublicKey().serialize().hex()

  merit: Merit = Merit()
  dataFilter: SpamFilter = SpamFilter(5)

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

  #Create two Datas.
  datas: List[Data] = [Data(bytes(32), edPubKey)]
  datas.append(Data(datas[0].hash, b"Hello there! General Kenobi."))

  for data in datas:
    #Sign them and have them beat the spam filter.
    data.sign(edPrivKey)
    data.beat(dataFilter)

    #Transmit them.
    rpc.meros.liveTransaction(data)

  #Verify both.
  verifs: List[SignedVerification] = [
    SignedVerification(datas[0].hash),
    SignedVerification(datas[1].hash)
  ]
  for verif in verifs:
    verif.sign(0, blsPrivKey)

  #Only transmit the second.
  rpc.meros.signedElement(verifs[1])
  sleep(1.5)

  #Verify the block template has no verifications.
  if bytes.fromhex(
    rpc.call("merit", "getBlockTemplate", {"miner": blsPubKey})["header"]
  )[36 : 68] != bytes(32):
    raise TestError("Block template has Verification Packets.")

  #Transmit the first signed verification.
  rpc.meros.signedElement(verifs[0])
  sleep(1.5)

  #Verify the block template has both verifications.
  template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", {"miner": blsPubKey})
  template["header"] = bytes.fromhex(template["header"])
  packets: List[VerificationPacket] = [VerificationPacket(datas[0].hash, [0]), VerificationPacket(datas[1].hash, [0])]
  if template["header"][36 : 68] != BlockHeader.createContents(packets):
    raise TestError("Block template doesn't have both Verification Packets.")

  #Mine the Block.
  block = Block(
    BlockHeader(
      0,
      block.header.hash,
      BlockHeader.createContents(packets),
      len(packets),
      template["header"][-43 : -39],
      BlockHeader.createSketchCheck(template["header"][-43 : -39], packets),
      0,
      int.from_bytes(template["header"][-4:], byteorder="little")
    ),
    BlockBody(
      packets,
      [],
      Signature.aggregate([verifs[0].signature, verifs[1].signature])
    )
  )
  if block.header.serializeHash()[:-4] != template["header"]:
    raise TestError("Failed to recreate the header.")

  block.mine(blsPrivKey, merit.blockchain.difficulty())
  merit.blockchain.add(block)

  rpc.call(
    "merit",
    "publishBlock",
    {
      "id": template["id"],
      "header": (
        template["header"] +
        block.header.proof.to_bytes(4, byteorder="little") +
        block.header.signature
      ).hex()
    }
  )

  verifyBlockchain(rpc, merit.blockchain)
