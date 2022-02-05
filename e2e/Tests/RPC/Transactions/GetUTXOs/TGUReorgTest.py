from typing import Dict, List, Tuple, Union, Any
import json

import bech32ref.segwit_addr as segwit_addr
from pytest import raises

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import verify
from e2e.Tests.Errors import TestError, SuccessError

def createSend(
  rpc: RPC,
  inputs: List[Union[Claim, Send]],
  to: bytes,
  key: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
) -> Send:
  pub: bytes = key.get_verifying_key()
  actualInputs: List[Tuple[bytes, int]] = []
  outputs: List[Tuple[bytes, int]] = [(to, 1)]
  toSpend: int = 0
  for txInput in inputs:
    if isinstance(txInput, Claim):
      actualInputs.append((txInput.hash, 0))
      toSpend += txInput.amount
    else:
      for n in range(len(txInput.outputs)):
        if txInput.outputs[n][0] == key.get_verifying_key():
          actualInputs.append((txInput.hash, n))
          toSpend += txInput.outputs[n][1]
  if toSpend > 1:
    outputs.append((pub, toSpend - 1))

  send: Send = Send(actualInputs, outputs)
  send.sign(key)
  send.beat(SpamFilter(3))
  if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
    raise TestError("Meros didn't broadcast back a Send.")
  return send

def reorg(
  rpc: RPC,
  alt: Blockchain
) -> None:
  #Sync up the new Blockchain.
  header: bytes = rpc.meros.liveBlockHeader(alt.blocks[-1].header)
  #Use the genesis as the default value for this outer defined variable.
  lastBlock: Block = alt.blocks[0]
  while True:
    req: bytes = rpc.meros.sync.recv()
    if MessageType(req[0]) == MessageType.BlockListRequest:
      blockList: List[bytes] = []
      for block in alt.blocks:
        if block.header.hash == req[2:]:
          break
        blockList.append(block.header.hash)
      blockList = blockList[-req[1]:]
      blockList.reverse()
      rpc.meros.blockList(blockList)

    elif MessageType(req[0]) == MessageType.BlockHeaderRequest:
      reqHash: bytes = req[1:]
      for block in alt.blocks:
        if reqHash == block.header.hash:
          rpc.meros.syncBlockHeader(block.header)
          break

    elif MessageType(req[0]) == MessageType.BlockBodyRequest:
      reqHash: bytes = req[1:-4]
      for block in alt.blocks:
        if reqHash == block.header.hash:
          lastBlock = block
          rpc.meros.rawBlockBody(block, 5)
          break

    elif MessageType(req[0]) == MessageType.SketchHashRequests:
      rpc.meros.packet(lastBlock.body.packets[0])

      #If we've sent the last BlockBody, and its packets, we've synced the chain.
      if lastBlock.header.hash == alt.blocks[-1].header.hash:
        break

  if header != rpc.meros.live.recv():
    raise TestError("Meros didn't broadcast back the alt chain's header.")

def TGUReorgTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def test() -> None:
    recipient: Ristretto.SigningKey = Ristretto.SigningKey(b'\1' * 32)
    recipientPub: bytes = recipient.get_verifying_key()
    address: str = segwit_addr.encode("mr", 1, recipientPub)

    #Create a Send.
    send: Send = Send.fromJSON(vectors["send"])
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    verify(rpc, send.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != [{"hash": send.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a confirmed Transaction's outputs as UTXOs.")
    #Spend it, with a newer Mint as an input as well so we can prune it without pruning the original.
    newerSend: Send = createSend(rpc, [Claim.fromJSON(vectors["newerMintClaim"])], recipientPub)
    _: Send = createSend(rpc, [send, newerSend], bytes(32), recipient)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros thinks the recipient has UTXOs.")

    #Remove the spending Send by pruning its ancestor (a Mint).
    reorg(rpc, Blockchain.fromJSON(vectors["blocksWithoutNewerMint"]))
    #Meros should add back its parent as an UTXO.
    if rpc.call("transactions", "getUTXOs", {"address": address}) != [{"hash": send.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a Transaction without spenders as an UTXO.")
    #Remove the original Send and verify its outputs are no longer considered UTXOs.
    reorg(rpc, Blockchain.fromJSON(vectors["blocksWithoutOlderMint"]))
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't remove the outputs of a pruned Transaction as UTXOs.")

    raise SuccessError()

  #Send Blocks so we have a Merit Holder who can instantly verify Transactions, not to mention Mints.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: test}).live()
