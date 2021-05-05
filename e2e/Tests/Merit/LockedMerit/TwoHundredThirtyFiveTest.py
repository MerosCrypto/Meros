from typing import Dict, Any
from time import sleep

import e2e.Libs.Ristretto.ed25519 as ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Blockchain import BlockHeader
from e2e.Classes.Merit.Blockchain import BlockBody
from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Transactions.Data import Data

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-locals,too-many-statements
def TwoHundredThirtyFiveTest(
  rpc: RPC
) -> None:
  blockchain: Blockchain = Blockchain()
  dataFilter: SpamFilter = SpamFilter(5)

  edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  edPubKey: bytes = edPrivKey.get_verifying_key()

  #Mine one Block to the node.
  blsPrivKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMeritHolderKey")))
  blsPubKey: bytes = blsPrivKey.toPublicKey().serialize()

  #Call getBlockTemplate just to get an ID.
  #Skips the need to write a sync loop for the BlockBody.
  template: Dict[str, Any] = rpc.call(
    "merit",
    "getBlockTemplate",
    {"miner": blsPubKey.hex()}
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

  #Send Meros a Data and receive its Verification to make sure it's verifying Transactions in the first place.
  data: Data = Data(bytes(32), edPubKey)
  data.sign(edPrivKey)
  data.beat(dataFilter)

  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
  if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
    raise TestError("Meros didn't send back the Data.")
  if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
    raise TestError("Meros didn't send us its SignedVerification.")

  #Close our connection and mine 8 Blocks so its Merit is locked.
  rpc.meros.live.connection.close()
  for _ in range(8):
    block = Block(
      BlockHeader(
        0,
        blockchain.blocks[-1].header.hash,
        bytes(32),
        0,
        bytes(4),
        bytes(32),
        0,
        blockchain.blocks[-1].header.time + 1200,
        0
      ),
      BlockBody()
    )
    #Reusing its key is fine as mining doesn't count as participation.
    block.mine(blsPrivKey, blockchain.difficulty())
    blockchain.add(block)

  #Sleep 30 seconds to make sure Meros noted we disconnected, and then reconnect.
  sleep(30)
  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

  #Sync the Blocks.
  for b in range(8):
    header: bytes = rpc.meros.liveBlockHeader(blockchain.blocks[b + 2].header)
    rpc.meros.handleBlockBody(blockchain.blocks[b + 2])
    if rpc.meros.live.recv() != header:
      raise TestError("Meros didn't send back the header.")
    if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
      raise TestError("Meros didn't verify this Block's data.")

  #Verify its Merit is locked.
  #Theoretically, all code after this check is unecessary.
  #Meros verifies a Block's Data after updating its State.
  #Therefore, if the above last Block had its Data verified, this issue should be closed.
  #That said, the timing is a bit too tight for comfort.
  #Better safe than sorry. Hence why the code after this check exists.
  if rpc.call("merit", "getMerit", {"nick": 0})["status"] != "Locked":
    raise TestError("Merit wasn't locked when it was supposed to be.")

  #Send it a Transaction and make sure Meros verifies it, despite having its Merit locked.
  data = Data(data.hash, edPubKey)
  data.sign(edPrivKey)
  data.beat(dataFilter)

  if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
    raise TestError("Meros didn't send back the Data.")
  if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
    raise TestError("Meros didn't send us its SignedVerification.")
