from typing import Dict, Any
import json

import bech32ref.segwit_addr as segwit_addr

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import verify
from e2e.Tests.Errors import TestError

def TGUImmediatelyTest(
  rpc: RPC
) -> None:
  recipient: Ristretto.SigningKey = Ristretto.SigningKey(b'\1' * 32)
  recipientPub: bytes = recipient.get_verifying_key()
  address: str = segwit_addr.encode("mr", 1, recipientPub)

  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  send: Send = Send.fromJSON(vectors["send"])
  spendingSend: Send = Send.fromJSON(vectors["spendingSend"])

  def start() -> None:
    #Send the Send.
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros considered an unconfirmed Transaction's outputs as UTXOs.")

    #Immediately spend it.
    if rpc.meros.liveTransaction(spendingSend) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a Transaction's inputs as spent.")

    #Verify the Send and make sure it's not considered as a valid UTXO.
    verify(rpc, send.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros considered a just confirmed Transaction with a spender's outputs as UTXOs.")

  def verified() -> None:
    #Verify the spender and verify the state is unchanged.
    verify(rpc, spendingSend.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a verified Transaction's inputs as spent.")

  def finalizedSend() -> None:
    #Sanity check the spending TX has yet to also finalize.
    if rpc.call("consensus", "getStatus", {"hash": spendingSend.hash.hex()})["finalized"]:
      raise Exception("Test meant to only finalize the first Send, not both.")

    #Verify the state is unchanged.
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a verified Transaction's inputs as spent after the input finalized.")

  def finalizedSpendingSend() -> None:
    #Verify the state is unchanged.
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a finalized Transaction's inputs as spent.")

  Liver(
    rpc,
    vectors["blockchain"],
    transactions,
    {
      50: start,
      51: verified,
      56: finalizedSend,
      57: finalizedSpendingSend
    }
  ).live()
