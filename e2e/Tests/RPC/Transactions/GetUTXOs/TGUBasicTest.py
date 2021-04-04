from typing import Dict, Any
import json

import ed25519
from bech32 import convertbits, bech32_encode
from pytest import raises

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import createSend, verify, mineBlock
from e2e.Tests.Errors import TestError, SuccessError

def TGUBasicTest(
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

    #Create a Send.
    send: Send = createSend(rpc, [Claim.fromJSON(vectors["olderMint"])], recipientPub)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros considered an unconfirmed Transaction's outputs as UTXOs.")

    #Verify the Send and make sure it's considered as a valid UTXO.
    verify(rpc, send.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != [{"hash": send.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a confirmed Transaction's outputs as UTXOs.")

    #Mine a Block to stagger finalization.
    mineBlock(rpc)

    #Spend it.
    spendingSend: Send = createSend(rpc, [send], bytes(32), recipient)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a Transaction's inputs as spent.")

    #Verify the spender and verify the state is unchanged.
    verify(rpc, spendingSend.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a verified Transaction's inputs as spent.")

    #Mine 5 Blocks to finalize the first Send and verify the state is unchanged.
    for _ in range(5):
      mineBlock(rpc)
    #Sanity check the spending TX has yet to also finalize.
    if rpc.call("consensus", "getStatus", {"hash": spendingSend.hash.hex()})["finalized"]:
      raise Exception("Test meant to only finalize the first Send, not both.")
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a verified Transaction's inputs as spent after the input finalized.")

    #Finalize the spending Send and verify the state is unchanged.
    mineBlock(rpc)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a finalized Transaction's inputs as spent.")

    raise SuccessError()

  #Send Blocks so we have a Merit Holder who can instantly verify Transactions, not to mention Mints.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: actualTest}).live()
