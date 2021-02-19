from typing import Dict, Any
import json

import ed25519

from e2e.Classes.Transactions.Mint import Mint
from e2e.Classes.Transactions.Transactions import Claim, Send, Data, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Merit.Merit import Merit

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-statements
def GetTransactionTest(
  rpc: RPC
) -> None:
  privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  pubKey: ed25519.VerifyingKey = privKey.get_verifying_key()

  sendFilter: SpamFilter = SpamFilter(3)
  dataFilter: SpamFilter = SpamFilter(5)

  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/ClaimedMint.json", "r") as file:
    vectors = json.loads(file.read())

  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  if len(transactions.txs) != 1:
    raise Exception("Transactions DAG doesn't have just the Claim.")
  claim: Claim = Claim.fromTransaction(next(iter(transactions.txs.values())))

  send: Send = Send(
    [(claim.hash, 0)],
    [(
      ed25519.SigningKey(b'\1' * 32).get_verifying_key().to_bytes(),
      claim.amount
    )]
  )
  send.sign(privKey)
  send.beat(sendFilter)

  data: Data = Data(bytes(32), pubKey.to_bytes())
  data.sign(privKey)
  data.beat(dataFilter)

  def sendAndVerify() -> None:
    rpc.meros.liveTransaction(send)
    rpc.meros.liveTransaction(data)
    rpc.meros.live.recv()
    rpc.meros.live.recv()

    #We now have a Mint, a Claim, a Send, a Data, a lion, a witch, and a wardrobe.

    #Check the Mint.
    mint: Mint = Merit.fromJSON(vectors["blockchain"]).mints[0]
    #pylint: disable=invalid-name
    EXPECTED_MINT: Dict[str, Any] = {
      "descendant": "Mint",
      "inputs": [],
      "outputs": [
        {
          "amount": str(txOutput[1]),
          "nick": txOutput[0]
        } for txOutput in mint.outputs
      ],
      "hash": mint.hash.hex().upper()
    }
    #Also sanity check against the in-house JSON.
    if mint.toJSON() != EXPECTED_MINT:
      raise TestError("Python's Mint toJSON doesn't match the spec.")
    if rpc.call("transactions", "getTransaction", {"hash": mint.hash.hex()}) != EXPECTED_MINT:
      raise TestError("getTransaction didn't report the Mint properly.")

    #Check the Claim.
    #pylint: disable=invalid-name
    EXPECTED_CLAIM: Dict[str, Any] = {
      "descendant": "Claim",
      "inputs": [
        {
          "hash": txInput[0].hex().upper(),
          "nonce": txInput[1]
        } for txInput in claim.inputs
      ],
      "outputs": [{
        "amount": str(claim.amount),
        "key": claim.output.hex().upper()
      }],
      "hash": claim.hash.hex().upper(),
      "signature": claim.signature.hex().upper()
    }
    if claim.amount == 0:
      raise Exception("Python didn't instantiate the Claim with an amount, leading to invalid testing methodology.")
    if claim.toJSON() != EXPECTED_CLAIM:
      raise TestError("Python's Claim toJSON doesn't match the spec.")
    if rpc.call("transactions", "getTransaction", {"hash": claim.hash.hex()}) != EXPECTED_CLAIM:
      raise TestError("getTransaction didn't report the Claim properly.")

    #Check the Send.
    #pylint: disable=invalid-name
    EXPECTED_SEND: Dict[str, Any] = {
      "descendant": "Send",
      "inputs": [
        {
          "hash": txInput[0].hex().upper(),
          "nonce": txInput[1]
        } for txInput in send.inputs
      ],
      "outputs": [
        {
          "amount": str(txOutput[1]),
          "key": txOutput[0].hex().upper()
        } for txOutput in send.outputs
      ],
      "hash": send.hash.hex().upper(),
      "signature": send.signature.hex().upper(),
      "proof": send.proof
    }
    if send.toJSON() != EXPECTED_SEND:
      raise TestError("Python's Send toJSON doesn't match the spec.")
    if rpc.call("transactions", "getTransaction", {"hash": send.hash.hex()}) != EXPECTED_SEND:
      raise TestError("getTransaction didn't report the Send properly.")

    #Check the Data.
    #pylint: disable=invalid-name
    EXPECTED_DATA: Dict[str, Any] = {
      "descendant": "Data",
      "inputs": [{
        "hash": data.txInput.hex().upper()
      }],
      "outputs": [],
      "hash": data.hash.hex().upper(),
      "data": data.data.hex().upper(),
      "signature": data.signature.hex().upper(),
      "proof": data.proof
    }
    if data.toJSON() != EXPECTED_DATA:
      raise TestError("Python's Data toJSON doesn't match the spec.")
    if rpc.call("transactions", "getTransaction", {"hash": data.hash.hex()}) != EXPECTED_DATA:
      raise TestError("getTransaction didn't report the Data properly.")

    #Non-existent hash; should cause an IndexError
    nonExistentHash: str = data.hash.hex()
    if data.hash[0] == "0":
      nonExistentHash = "1" + nonExistentHash[1:]
    else:
      nonExistentHash = "0" + nonExistentHash[1:]
    try:
      rpc.call("transactions", "getTransaction", {"hash": nonExistentHash})
    except TestError as e:
      if str(e) != "-2 Transaction not found.":
        raise TestError("getTransaction didn't raise IndexError on a non-existent hash.")

    #Invalid argument; should cause a ParamError
    #This is still a hex value
    try:
      rpc.call("transactions", "getTransaction", {"hash": "00" + data.hash.hex()})
      raise TestError("Meros didn't error when we asked for a 33-byte hex value.")
    except TestError as e:
      if str(e) != "-32602 Invalid params.":
        raise TestError("getTransaction didn't raise on invalid parameters.")

  Liver(rpc, vectors["blockchain"], transactions, {8: sendAndVerify}).live()
