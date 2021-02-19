from typing import Dict, Any
import json

import ed25519

from e2e.Classes.Transactions.Transactions import Claim, Send, Data, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Transactions.Verify import verifyTransaction

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-statements
def PublishTransactionTest(
  rpc: RPC
) -> None:
  privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  pubKey: ed25519.VerifyingKey = privKey.get_verifying_key()

  sentToKey: ed25519.SigningKey = ed25519.SigningKey(b'\1' * 32)

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
    [(sentToKey.get_verifying_key().to_bytes(), claim.amount)]
  )
  send.sign(privKey)
  send.beat(sendFilter)

  data: Data = Data(bytes(32), pubKey.to_bytes())
  data.sign(privKey)
  data.beat(dataFilter)

  def publishAndVerify() -> None:
    if not rpc.call(
      "transactions",
      "publishTransaction",
      {
        "type": "Claim",
        "transaction": claim.serialize().hex()
      }
    ):
      raise TestError("Publishing a valid Transaction didn't return true.")

    if not rpc.call(
      "transactions",
      "publishTransaction",
      {
        "type": "Send",
        "transaction": send.serialize().hex()
      }
    ):
      raise TestError("Publishing a valid Transaction didn't return true.")

    if not rpc.call(
      "transactions",
      "publishTransaction",
      {
        "type": "Data",
        "transaction": data.serialize().hex()
      }
    ):
      raise TestError("Publishing a valid Transaction didn't return true.")

    #Verify all three were entered properly.
    verifyTransaction(rpc, claim)
    verifyTransaction(rpc, send)
    verifyTransaction(rpc, data)

    #Create a new Send/Data and publish them without work.
    print("Handling Send")
    sendSentWithoutWork: Send = Send([(send.hash, 0)], [(pubKey.to_bytes(), claim.amount)])
    sendSentWithoutWork.sign(sentToKey)
    sendSentWithoutWork.beat(sendFilter)

    dataSentWithoutWork: Data = Data(bytes(32), sentToKey.get_verifying_key().to_bytes())
    dataSentWithoutWork.sign(sentToKey)
    dataSentWithoutWork.beat(dataFilter)

    if not rpc.call(
      "transactions",
      "publishTransactionWithoutWork",
      {
        "type": "Send",
        "transaction": sendSentWithoutWork.serialize()[:-4].hex()
      }
    ):
      raise TestError("Publishing a valid Transaction without work didn't return true.")

    if not rpc.call(
      "transactions",
      "publishTransactionWithoutWork",
      {
        "type": "Data",
        "transaction": dataSentWithoutWork.serialize()[:-4].hex()
      }
    ):
      raise TestError("Publishing a valid Transaction without work didn't return true.")

    #Call verify now, which will test ours with work against Meros's with generated work.
    #Both should terminate on the earliest valid proof, making them identical.
    verifyTransaction(rpc, sendSentWithoutWork)
    verifyTransaction(rpc, dataSentWithoutWork)

    #Re-publishing a Transaction should still return true.
    if not rpc.call(
      "transactions",
      "publishTransaction",
      {
        "type": "Data",
        "transaction": data.serialize().hex()
      }
    ):
      raise TestError("Publishing an existing Transaction didn't return true.")

    #No arguments.
    try:
      rpc.call("transactions", "publishTransaction")
    except TestError as e:
      if str(e) != "-32602 Invalid params.":
        raise TestError("publishTransaction didn't error when passed no arguments.")

    #Invalid type.
    try:
      rpc.call(
        "transactions",
        "publishTransaction",
        {
          "type": "",
          "transaction": data.serialize().hex()
        }
      )
      raise TestError("")
    except TestError as e:
      if str(e) != "-3 Invalid Transaction type specified.":
        raise TestError("publishTransaction didn't error when passed an invalid type.")

    #Data sent with Send as a type.
    try:
      rpc.call(
        "transactions",
        "publishTransaction",
        {
          "type": "Send",
          "transaction": data.serialize().hex()
        }
      )
      raise TestError("")
    except TestError as e:
      if str(e) != "-3 Transaction is invalid: parseSend handed the wrong amount of data..":
        raise TestError("publishTransaction didn't error when passed a non-parsable Send (a Data).")

    #Invalid Data (signature).
    invalidData: Data = Data(bytes(32), sentToKey.get_verifying_key().to_bytes())
    newData: bytearray = bytearray(invalidData.data)
    newData[-1] = newData[-1] ^ 1
    invalidData.data = bytes(newData)
    invalidData.sign(sentToKey)
    invalidData.beat(dataFilter)
    try:
      rpc.call(
        "transactions",
        "publishTransaction",
        {
          "type": "Data",
          "transaction": invalidData.serialize().hex()
        }
      )
      raise TestError("")
    except TestError as e:
      if str(e) != "-3 Transaction is invalid: Data has an invalid Signature..":
        raise TestError("publishTransaction didn't error when passed an invalid Transaction.")

    #Spam.
    spamData: Data = data
    if spamData.proof == 0:
      spamData = dataSentWithoutWork
    if spamData.proof == 0:
      raise Exception("Neither Data is considered as Spam.")
    spamData.proof = 0

    try:
      rpc.call(
        "transactions",
        "publishTransaction",
        {
          "type": "Data",
          "transaction": spamData.serialize().hex()
        }
      )
      raise TestError("")
    except TestError as e:
      if str(e) != "1 Transaction didn't beat the spam filter.":
        raise TestError("publishTransaction didn't error when passed a Transaction which didn't beat its difficulty.")

    """
    TODO: Test auth requirement
    """

  Liver(rpc, vectors["blockchain"][:-1], transactions, {7: publishAndVerify}).live()
