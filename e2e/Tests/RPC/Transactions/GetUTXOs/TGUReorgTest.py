#TODO: Move reorgPast's Block generation to the vectors.

from typing import Dict, List, Any
import json

import ed25519
from bech32 import convertbits, bech32_encode
from pytest import raises

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Merit.Merit import Merit

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import createSend, verify
from e2e.Tests.Errors import TestError, SuccessError

#Should be called once already not connected to the node.
def reorgPast(
  rpc: RPC,
  mint: bytes
) -> None:
  #Get the current Blockchain up to the fork point.
  blocksJSON: List[Dict[str, Any]] = []
  for b in range(rpc.call("merit", "getHeight")):
    blockJSON: Dict[str, Any] = rpc.call("merit", "getBlock", {"block": b})
    if blockJSON["hash"] == mint.hex().upper():
      break
    blocksJSON.append(blockJSON)

  merit: Merit = Merit.fromJSON(blocksJSON)
  while len(merit.blockchain.blocks) <= rpc.call("merit", "getHeight"):
    merit.add(
      PrototypeBlock(
        #Use a slightly faster time differential.
        merit.blockchain.blocks[-1].header.time +
        ((merit.blockchain.blocks[-1].header.time - merit.blockchain.blocks[-2].header.time) - 1)
      ).finish(1, merit)
    )

  #Sync up the new Blockchain.
  header: bytes = rpc.meros.liveBlockHeader(merit.blockchain.blocks[-1].header)
  lastBlock: BlockBody
  while True:
    req: bytes = rpc.meros.sync.recv()
    if MessageType(req[0]) == MessageType.BlockListRequest:
      blockList: List[bytes] = []
      for block in merit.blockchain.blocks:
        if block.header.hash == req[2:]:
          break
        blockList.append(block.header.hash)
      blockList = blockList[-req[1]:]
      blockList.reverse()
      rpc.meros.blockList(blockList)

    elif MessageType(req[0]) == MessageType.BlockHeaderRequest:
      reqHash: bytes = req[1:]
      for block in merit.blockchain.blocks:
        if reqHash == block.header.hash:
          rpc.meros.syncBlockHeader(block.header)
          break

    elif MessageType(req[0]) == MessageType.BlockBodyRequest:
      reqHash: bytes = req[1:-4]
      for block in merit.blockchain.blocks:
        if reqHash == block.header.hash:
          lastBlock = block
          rpc.meros.rawBlockBody(block, 5)
          break

    elif MessageType(req[0]) == MessageType.SketchHashRequests:
      rpc.meros.packet(lastBlock.body.packets[0])

      #If we've sent the last BlockBody, and its packets, we've synced the chain.
      if lastBlock.header.hash == merit.blockchain.blocks[-1].header.hash:
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

  def actualTest() -> None:
    recipient: ed25519.SigningKey = ed25519.SigningKey(b'\1' * 32)
    recipientPub: bytes = recipient.get_verifying_key().to_bytes()
    address: str = bech32_encode("mr", convertbits(bytes([0]) + recipientPub, 8, 5))

    olderClaim: Claim = Claim.fromJSON(vectors["olderMint"])
    newerClaim: Claim = Claim.fromJSON(vectors["newerMint"])

    #Create a Send.
    send: Send = createSend(rpc, [olderClaim], recipientPub)
    verify(rpc, send.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != [{"hash": send.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a confirmed Transaction's outputs as UTXOs.")
    #Spend it, with a newer Mint as an input as well so we can prune it without pruning the original.
    newerSend: Send = createSend(rpc, [newerClaim], recipientPub)
    _: Send = createSend(rpc, [send, newerSend], bytes(32), recipient)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros thinks the recipient has UTXOs.")

    #Remove the spending Send by pruning its ancestor (a Mint).
    reorgPast(rpc, newerClaim.inputs[0][0])
    #Meros should add back its parent as an UTXO.
    if rpc.call("transactions", "getUTXOs", {"address": address}) != [{"hash": send.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a Transaction without spenders as an UTXO.")
    #Remove the original Send and verify its outputs are no longer considered UTXOs.
    reorgPast(rpc, olderClaim.inputs[0][0])
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't remove the outputs of a pruned Transaction as UTXOs.")

    raise SuccessError()

  #Send Blocks so we have a Merit Holder who can instantly verify Transactions, not to mention Mints.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: actualTest}).live()
