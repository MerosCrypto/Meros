#Since personal_send internally called personal_getTransactionTemplate, this has heavy overlap with the WatchWallet test.
#That test is what explicitly handles personal_getTransactionTemplate.
#That said, that test also uses personal_send, and thanks to it, personal_send is a much simpler/more concise test.
#So while WatchWalletTest was heavily developed before this was started, this will finish first as concside and clean.

from typing import Dict, List, Any
from time import sleep
import json

from bech32ref.segwit_addr import Encoding, convertbits, bech32_encode
from pytest import raises

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey
from e2e.Libs.RandomX import RandomX

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Meros.Meros import MessageType, Meros
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Personal.Lib import getChangePublicKey, decodeAddress
from e2e.Tests.Errors import TestError, SuccessError

def verify(
  rpc: RPC,
  tx: bytes
) -> None:
  sv: SignedVerification = SignedVerification(tx)
  sv.sign(0, PrivateKey(0))
  if rpc.meros.signedElement(sv) != rpc.meros.live.recv():
    raise TestError("Meros didn't send back a Verification.")

def createSend(
  rpc: RPC,
  claim: Claim,
  to: bytes
) -> bytes:
  send: Send = Send([(claim.hash, 0)], [(to, claim.amount)])
  send.sign(Ristretto.SigningKey(b'\0' * 32))
  send.beat(SpamFilter(3))
  if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
    raise TestError("Meros didn't send back a Send.")
  verify(rpc, send.hash)
  return send.hash

def sortUTXOs(
  utxos: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
  return sorted(utxos, key=lambda utxo: utxo["hash"] + str(utxo["nonce"]))

def checkSend(
  rpc: RPC,
  sendHash: str,
  expected: Dict[str, Any]
) -> None:
  send: Dict[str, Any] = rpc.call("transactions", "getTransaction", {"hash": sendHash})
  serialized: bytes = Send.fromJSON(send).serialize()
  del send["signature"]
  del send["proof"]

  expected["descendant"] = "Send"
  expected["hash"] = sendHash
  if sortUTXOs(send["inputs"]) != sortUTXOs(expected["inputs"]):
    raise TestError("Send inputs weren't as expected.")
  del send["inputs"]
  del expected["inputs"]
  if send != expected:
    raise TestError("Send wasn't as expected.")

  if rpc.meros.live.recv() != (MessageType.Send.toByte() + serialized):
    raise TestError("Meros didn't broadcast a Send it created.")

#pylint: disable=too-many-statements,too-many-locals
def PersonalSendTest(
  rpc: RPC
) -> None:
  #Load the vectors.
  #Uses the WatchWallet test's vectors for the reasons noted above.
  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Personal/WatchWallet.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #The order of the Claims isn't relevant to this test.
  claims: List[Claim] = []
  for tx in transactions.txs.values():
    claims.append(Claim.fromTransaction(tx))

  def test() -> None:
    #Send to the first address from outside the Wallet. First address is now funded.
    sendHash: bytes = createSend(rpc, claims[0], decodeAddress(rpc.call("personal", "getAddress")))

    #Send to the second address with all of the funds. Second address is now funded.
    #Tests send's minimal case (single input, no change).
    nextAddr: str = rpc.call("personal", "getAddress")
    sends: List[str] = [
      rpc.call(
        "personal",
        "send",
        {"outputs": [{"address": nextAddr, "amount": str(claims[0].amount)}]}
      )
    ]
    checkSend(
      rpc,
      sends[-1],
      {
        "inputs": [{"hash": sendHash.hex().upper(), "nonce": 0}],
        "outputs": [{
          "key": decodeAddress(nextAddr).hex().upper(),
          "amount": str(claims[0].amount)
        }]
      }
    )
    verify(rpc, bytes.fromhex(sends[-1]))

    #Send to the third address with some of the funds. Third and change addresses are now funded.
    #Tests send's capability to create a change output.
    mnemonic: str = rpc.call("personal", "getMnemonic")
    nextAddr = rpc.call("personal", "getAddress")
    sends.append(
      rpc.call(
        "personal",
        "send",
        {"outputs": [{"address": nextAddr, "amount": str(claims[0].amount - 1)}]}
      )
    )
    checkSend(
      rpc,
      sends[-1],
      {
        "inputs": [{"hash": sends[-2], "nonce": 0}],
        "outputs": [
          {
            "key": decodeAddress(nextAddr).hex().upper(),
            "amount": str(claims[0].amount - 1)
          },
          {
            "key": getChangePublicKey(mnemonic, "", 0).hex().upper(),
            "amount": "1"
          }
        ]
      }
    )
    verify(rpc, bytes.fromhex(sends[-1]))

    #Send all funds out of Wallet.
    #Tests MuSig signing and change UTXO detection.
    privKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
    pubKey: bytes = privKey.get_verifying_key()
    sends.append(
      rpc.call(
        "personal",
        "send",
        {
          "outputs": [{
            "address": bech32_encode("mr", convertbits(bytes([0]) + pubKey, 8, 5), Encoding.BECH32M),
            "amount": str(claims[0].amount)
          }]
        }
      )
    )
    checkSend(
      rpc,
      sends[-1],
      {
        "inputs": [{"hash": sends[-2], "nonce": 0}, {"hash": sends[-2], "nonce": 1}],
        "outputs": [{
          "key": pubKey.hex().upper(),
          "amount": str(claims[0].amount)
        }]
      }
    )
    verify(rpc, bytes.fromhex(sends[-1]))

    #Clear Wallet. Set a password this time around to make sure the password is properly carried.
    #Send two instances of funds to the first address.
    rpc.call("personal", "setWallet", {"password": "test"})
    mnemonic = rpc.call("personal", "getMnemonic")
    nodeKey: bytes = decodeAddress(rpc.call("personal", "getAddress"))
    send: Send = Send([(bytes.fromhex(sends[-1]), 0)], [(nodeKey, claims[0].amount // 2), (nodeKey, claims[0].amount // 2)])
    send.sign(Ristretto.SigningKey(b'\0' * 32))
    send.beat(SpamFilter(3))
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back a Send.")
    verify(rpc, send.hash)
    sends = [send.hash.hex().upper()]

    #Send to self.
    #Tests send's capability to handle multiple UTXOs per key/lack of aggregation when all keys are the same/multiple output Sends.
    nextAddr = rpc.call("personal", "getAddress")
    changeKey: bytes = getChangePublicKey(mnemonic, "test", 0)
    sends.append(
      rpc.call(
        "personal",
        "send",
        {"outputs": [{"address": nextAddr, "amount": str(claims[0].amount - 1)}], "password": "test"}
      )
    )
    checkSend(
      rpc,
      sends[-1],
      {
        "inputs": [{"hash": sends[-2], "nonce": 0}, {"hash": sends[-2], "nonce": 1}],
        "outputs": [
          {
            "key": decodeAddress(nextAddr).hex().upper(),
            "amount": str(claims[0].amount - 1)
          },
          {
            "key": changeKey.hex().upper(),
            "amount": "1"
          }
        ]
      }
    )
    verify(rpc, bytes.fromhex(sends[-1]))

    #Externally send to the second/change address.
    #Enables entering multiple instances of each key into MuSig, which is significant as we originally only used the unique keys.
    sends.append(createSend(rpc, claims[1], decodeAddress(nextAddr)).hex().upper())
    sends.append(createSend(rpc, claims[2], changeKey).hex().upper())

    #Check personal_getUTXOs.
    utxos: List[Dict[str, Any]] = [
      {
        "hash": sends[-3],
        "nonce": 0,
        "address": nextAddr
      },
      {
        "hash": sends[-3],
        "nonce": 1,
        "address": bech32_encode("mr", convertbits(bytes([0]) + changeKey, 8, 5), Encoding.BECH32M)
      },
      {
        "hash": sends[-2],
        "nonce": 0,
        "address": nextAddr
      },
      {
        "hash": sends[-1],
        "nonce": 0,
        "address": bech32_encode("mr", convertbits(bytes([0]) + changeKey, 8, 5), Encoding.BECH32M)
      }
    ]
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      raise TestError("personal_getUTXOs was incorrect.")
    for utxo in utxos:
      del utxo["address"]

    #Send to any address with all funds minus one.
    #Test MuSig signing, multiple inputs per key on account chains, change output creation to the next change key...
    sends.append(
      rpc.call(
        "personal",
        "send",
        {"outputs": [{"address": nextAddr, "amount": str(claims[0].amount + claims[1].amount + claims[2].amount - 1)}], "password": "test"}
      )
    )
    checkSend(
      rpc,
      sends[-1],
      {
        "inputs": utxos,
        "outputs": [
          {
            "key": decodeAddress(nextAddr).hex().upper(),
            "amount": str(claims[0].amount + claims[1].amount + claims[2].amount - 1)
          },
          {
            "key": getChangePublicKey(mnemonic, "test", 1).hex().upper(),
            "amount": "1"
          }
        ]
      }
    )
    verify(rpc, bytes.fromhex(sends[-1]))

    #Mine a Block so we can reboot the node without losing data.
    blsPrivKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMeritHolderKey")))
    for _ in range(6):
      template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", {"miner": blsPrivKey.toPublicKey().serialize().hex()})
      proof: int = -1
      tempHash: bytes = bytes()
      tempSignature: bytes = bytes()
      while (
        (proof == -1) or
        ((int.from_bytes(tempHash, "little") * template["difficulty"]) > int.from_bytes(bytes.fromhex("FF" * 32), "little"))
      ):
        proof += 1
        tempHash = RandomX(bytes.fromhex(template["header"]) + proof.to_bytes(4, "little"))
        tempSignature = blsPrivKey.sign(tempHash).serialize()
        tempHash = RandomX(tempHash + tempSignature)

      rpc.call("merit", "publishBlock", {"id": template["id"], "header": template["header"] + proof.to_bytes(4, "little").hex() + tempSignature.hex()})

    #Reboot the node and verify it still tracks the same change address.
    #Also reload the Wallet and verify it still tracks the same change address.
    #Really should be part of address discovery; we just have the opportunity right here.
    #Due to the timing of how the codebase was developed, and a personal frustration for how long this has taken...
    rpc.quit()
    sleep(3)
    rpc.meros = Meros(rpc.meros.db, rpc.meros.tcp, rpc.meros.rpc)
    if rpc.call(
      "personal",
      "getTransactionTemplate",
      {"outputs": [{"address": nextAddr, "amount": "1"}]}
    )["outputs"][1]["key"] != getChangePublicKey(mnemonic, "test", 2).hex().upper():
      raise TestError("Rebooting the node caused the WalletDB to stop tracking the next change address.")
    rpc.call("personal", "setAccount", rpc.call("personal", "getAccount"))
    if rpc.call(
      "personal",
      "getTransactionTemplate",
      {"outputs": [{"address": nextAddr, "amount": "1"}]}
    )["outputs"][1]["key"] != getChangePublicKey(mnemonic, "test", 2).hex().upper():
      raise TestError("Reloading the Wallet caused the WalletDB to stop tracking the next change address.")

    raise SuccessError()

  #Use a late enough block we can instantly verify transactions.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: test}).live()
