from typing import Dict, List, Any
import json

from bech32 import convertbits, bech32_encode
from pytest import raises

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transactions import Send, Data, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import verify, mineBlock
from e2e.Tests.Errors import TestError, SuccessError

def TGUUnverifyTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def test() -> None:
    recipient: Ristretto.SigningKey = Ristretto.SigningKey(b'\1' * 32)
    recipientPub: bytes = recipient.get_verifying_key()
    address: str = bech32_encode("mr", convertbits(bytes([0]) + recipientPub, 8, 5))

    otherRecipient: bytes = Ristretto.SigningKey(b'\2' * 32).get_verifying_key()
    otherAddress: str = bech32_encode("mr", convertbits(bytes([0]) + otherRecipient, 8, 5))

    #Create a Send.
    send: Send = Send.fromJSON(vectors["send"])
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros considered an unconfirmed Transaction's outputs as UTXOs.")
    verify(rpc, send.hash)

    #Finalize the parent.
    for _ in range(6):
      mineBlock(rpc)

    #Spend it.
    spendingSend: Send = Send.fromJSON(vectors["spendingSend"])
    if rpc.meros.liveTransaction(spendingSend) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back a Send.")
    verify(rpc, spendingSend.hash)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a verified Transaction's inputs as spent.")
    if rpc.call("transactions", "getUTXOs", {"address": otherAddress}) != [{"hash": spendingSend.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a verified Transaction's outputs as UTXOs.")

    #Unverify the spending Send. This would also unverify the parent if it wasn't finalized.
    #This is done via causing a Merit Removal.
    #Uses two competing Datas to not change the Send's status to competing.
    datas: List[Data] = [Data(bytes(32), recipientPub)]
    for _ in range(2):
      datas.append(Data(datas[0].hash, datas[-1].hash))
    for data in datas:
      data.sign(recipient)
      data.beat(SpamFilter(5))
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast back a Data.")
      verify(rpc, data.hash, mr=(datas[-1].hash == data.hash))
    #Verify the MeritRemoval happened and the spending Send is no longer verified.
    #These first two checks are more likely to symbolize a failure in testing methodology than Meros.
    if not rpc.call("merit", "getMerit", {"nick": 0})["malicious"]:
      raise TestError("Meros didn't create a Merit Removal.")
    if not rpc.call("consensus", "getStatus", {"hash": send.hash.hex()})["verified"]:
      raise TestError("Finalized Transaction became unverified.")
    if rpc.call("consensus", "getStatus", {"hash": spendingSend.hash.hex()})["verified"]:
      raise TestError("Meros didn't unverify a Transaction which is currently below the required threshold.")
    #Even after unverification, since the Transaction still exists, the input shouldn't be considered a UTXO.
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a unverified yet existing Transaction's inputs as spent.")
    #That said, its outputs should no longer be considered a UTXO.
    if rpc.call("transactions", "getUTXOs", {"address": otherAddress}) != []:
      raise TestError("Meros considered a unverified Transaction's outputs as UTXOs.")

    raise SuccessError()

  #Send Blocks so we have a Merit Holder who can instantly verify Transactions, not to mention Mints.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: test}).live()
