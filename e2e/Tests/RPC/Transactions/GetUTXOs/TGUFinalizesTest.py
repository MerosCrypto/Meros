#Tests a Transaction which is never verified, yet does finalize as the winner, creates UTXOs.

from typing import Dict, Any
import json

from bech32ref.segwit_addr import Encoding, convertbits, bech32_encode
from pytest import raises

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import verify, mineBlock
from e2e.Tests.Errors import TestError, SuccessError

def TGUFinalizesTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def test() -> None:
    recipient: Ristretto.SigningKey = Ristretto.SigningKey(b'\1' * 32)
    recipientPub: bytes = recipient.get_verifying_key()
    address: str = bech32_encode("mr", convertbits(bytes([0]) + recipientPub, 8, 5), Encoding.BECH32M)

    otherRecipient: bytes = Ristretto.SigningKey(b'\2' * 32).get_verifying_key()
    otherAddress: str = bech32_encode("mr", convertbits(bytes([0]) + otherRecipient, 8, 5), Encoding.BECH32M)

    #Create a Send.
    send: Send = Send.fromJSON(vectors["send"])
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros considered an unconfirmed Transaction's outputs as UTXOs.")
    verify(rpc, send.hash)

    #Spend it.
    spendingSend: Send = Send.fromJSON(vectors["spendingSend"])
    if rpc.meros.liveTransaction(spendingSend) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a Transaction's inputs as spent.")

    #Verify with another party, so it won't be majority verified, yet will still have a Verification.
    mineBlock(rpc, 1)
    verify(rpc, spendingSend.hash, 1)
    #Verify it didn't create a UTXO.
    if rpc.call("transactions", "getUTXOs", {"address": otherAddress}) != []:
      raise TestError("Unverified Transaction created a UTXO.")

    #Finalize.
    for _ in range(6):
      mineBlock(rpc)

    #Check the UTXOs were created.
    if rpc.call("transactions", "getUTXOs", {"address": otherAddress}) != [{"hash": spendingSend.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a finalized Transaction's outputs as UTXOs.")

    raise SuccessError()

  #Send Blocks so we have a Merit Holder who can instantly verify Transactions, not to mention Mints.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: test}).live()
