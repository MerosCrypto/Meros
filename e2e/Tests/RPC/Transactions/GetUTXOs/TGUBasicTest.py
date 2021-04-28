#Also tests transactions_getBalance.

from typing import Dict, Any
import json

import ed25519
from bech32 import convertbits, bech32_encode

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import verify
from e2e.Tests.Errors import TestError

def TGUBasicTest(
  rpc: RPC
) -> None:
  recipient: ed25519.SigningKey = ed25519.SigningKey(b'\1' * 32)
  recipientPub: bytes = recipient.get_verifying_key().to_bytes()
  address: str = bech32_encode("mr", convertbits(bytes([0]) + recipientPub, 8, 5))

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

    #Verify the Send and make sure it's considered as a valid UTXO.
    verify(rpc, send.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != [{"hash": send.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a confirmed Transaction's outputs as UTXOs.")
    if rpc.call("transactions", "getBalance", {"address": address}) != str(send.outputs[0][1]):
      raise TestError("transactions_getBalance didn't count an active UTXO.")

  def verified() -> None:
    #Spend it.
    if rpc.meros.liveTransaction(spendingSend) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a Transaction's inputs as spent.")
    if rpc.call("transactions", "getBalance", {"address": address}) != "0":
      raise TestError("transactions_getBalance counted a spent TXO.")

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
