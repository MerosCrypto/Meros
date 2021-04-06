from typing import Dict, Any
import json

from pytest import raises

from e2e.Classes.Transactions.Transactions import Claim, Data, Transactions
from e2e.Classes.Merit.Blockchain import BlockHeader, Block, Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def BroadcastTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/ClaimedMint.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])
  claim: Claim = Claim.fromTransaction(iter(transactions.txs.values()).__next__())
  mint: bytes = claim.inputs[0][0]

  def test() -> None:
    #Data.
    dataHash: str = rpc.call("personal", "data", {"data": "abc"})
    #Read the initial Data.
    if MessageType(rpc.meros.live.recv()[0]) != MessageType.Data:
      raise TestError("Meros didn't broadcast the initial Data.")
    #Read the actual Data.
    serializedData: bytes = rpc.meros.live.recv()
    if serializedData[1:] != Data.fromJSON(rpc.call("transactions", "getTransaction", {"hash": dataHash})).serialize():
      raise TestError("Meros didn't broadcast the created Data.")
    res: Any = rpc.call("network", "broadcast", {"transaction": dataHash})
    if not (isinstance(res, bool) and res):
      raise TestError("Broadcast didn't return true.")
    if rpc.meros.live.recv() != serializedData:
      raise TestError("Meros didn't broadcast a Transaction when told to.")

    #Block.
    header: BlockHeader = Block.fromJSON(vectors["blockchain"][0]).header
    rpc.call("network", "broadcast", {"block": header.hash.hex()})
    if rpc.meros.live.recv() != (MessageType.BlockHeader.toByte() + header.serialize()):
      raise TestError("Meros didn't broadcast the Blockheader.")

    #Data and Block.
    rpc.call("network", "broadcast", {"block": header.hash.hex(), "transaction": dataHash})
    if rpc.meros.live.recv() != serializedData:
      raise TestError("Meros didn't broadcast a Transaction when told to.")
    if rpc.meros.live.recv() != (MessageType.BlockHeader.toByte() + header.serialize()):
      raise TestError("Meros didn't broadcast the Blockheader.")

    #Non-existent Transaction.
    try:
      rpc.call("network", "broadcast", {"transaction": bytes(32).hex()})
      raise TestError()
    except TestError as e:
      if str(e) != "-2 Transaction not found.":
        raise TestError("Meros didn't error when told to broadcast a non-existent Transaction.")

    #Non-existent Block.
    try:
      rpc.call("network", "broadcast", {"block": bytes(32).hex()})
      raise TestError()
    except TestError as e:
      if str(e) != "-2 Block not found.":
        raise TestError("Meros didn't error when told to broadcast a non-existent Block.")

    #Mint.
    try:
      rpc.call("network", "broadcast", {"transaction": mint.hex()})
      raise TestError()
    except TestError as e:
      if str(e) != "-3 Transaction is a Mint.":
        raise TestError("Meros didn't error when told to broadcast a Mint.")

    #Genesis Block.
    try:
      rpc.call("network", "broadcast", {"block": Blockchain().blocks[0].header.hash.hex()})
      raise TestError()
    except TestError as e:
      if str(e) != "-3 Block is the genesis Block.":
        raise TestError("Meros didn't error when told to broadcast the genesis Block.")

  #Create and execute a Liver.
  Liver(rpc, vectors["blockchain"], transactions, callbacks={8: test}).live()
