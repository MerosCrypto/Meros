#https://github.com/MerosCrypto/Meros/issues/155

from typing import Dict, List, Any

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Blockchain import BlockHeader
from e2e.Classes.Merit.Blockchain import BlockBody
from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Classes.Transactions.Data import Data

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-locals,too-many-statements
def HundredFiftyFiveTest(
  rpc: RPC
) -> None:
  edPrivKeys: List[Ristretto.SigningKey] = [
    Ristretto.SigningKey(b'\0' * 32),
    Ristretto.SigningKey(b'\1' * 32)
  ]
  edPubKeys: List[bytes] = [
    edPrivKeys[0].get_verifying_key(),
    edPrivKeys[1].get_verifying_key()
  ]

  blsPrivKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMeritHolderKey")))
  blsPubKey: bytes = blsPrivKey.toPublicKey().serialize()

  blockchain: Blockchain = Blockchain()
  dataFilter: SpamFilter = SpamFilter(5)

  #Handshake with the node.
  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

  #Call getBlockTemplate just to get an ID.
  #Skips the need to write a sync loop for the BlockBody.
  template: Dict[str, Any] = rpc.call(
    "merit",
    "getBlockTemplate",
    {
      "miner": blsPubKey.hex()
    }
  )

  #Mine a Block.
  block = Block(
    BlockHeader(
      0,
      blockchain.blocks[0].header.hash,
      bytes(32),
      0,
      bytes(4),
      bytes(32),
      blsPubKey,
      blockchain.blocks[0].header.time + 1200,
      0
    ),
    BlockBody()
  )
  block.mine(blsPrivKey, blockchain.difficulty())
  blockchain.add(block)

  rpc.call(
    "merit",
    "publishBlock",
    {
      "id": template["id"],
      "header": block.header.serialize().hex()
    }
  )

  if MessageType(rpc.meros.live.recv()[0]) != MessageType.BlockHeader:
    raise TestError("Meros didn't broadcast the Block we just published.")
  #Ignore the Verification for the Block's Data.
  if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
    raise TestError("Meros didn't send the SignedVerification for the Block's Data.")

  datas: List[Data] = [
    Data(bytes(32), edPubKeys[0]),
    Data(bytes(32), edPubKeys[1])
  ]

  for d in range(len(datas)):
    datas[d].sign(edPrivKeys[d])
    datas[d].beat(dataFilter)

    #Send the Data and verify Meros sends it back.
    if rpc.meros.liveTransaction(datas[d]) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back the Data.")

    #Verify Meros sends back a Verification.
    res: bytes = rpc.meros.live.recv()
    if MessageType(res[0]) != MessageType.SignedVerification:
      raise TestError("Meros didn't send a SignedVerification.")

    verif: SignedVerification = SignedVerification(datas[d].hash)
    verif.sign(0, blsPrivKey)
    if res[1:] != verif.signedSerialize():
      raise TestError("Meros didn't send the correct SignedVerification.")
