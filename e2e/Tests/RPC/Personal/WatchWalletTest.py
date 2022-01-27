#Developed before, yet finished after, personal_send's test.
#PersonalSendTest is much cleaner and wraps getTransactionTemplate, meaning this really only needs to test from/change.
#Some old, overlapping test cases have been left in.

from typing import Dict, List, Any
from time import sleep
import json

from bech32ref.segwit_addr import Encoding, convertbits, bech32_encode

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Personal.Lib import getPublicKey, getChangePublicKey, getAddress
from e2e.Tests.Errors import TestError

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
  return send.hash

def verify(
  rpc: RPC,
  tx: bytes
) -> None:
  sv: SignedVerification = SignedVerification(tx)
  sv.sign(0, PrivateKey(0))
  if rpc.meros.signedElement(sv) != rpc.meros.live.recv():
    raise TestError("Meros didn't send back a Verification.")

def sortUTXOs(
  utxos: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
  return sorted(utxos, key=lambda utxo: utxo["hash"])

def checkTemplate(
  rpc: RPC,
  mnemonic: str,
  req: Dict[str, Any],
  inputs: List[Dict[str, Any]],
  outputs: List[Dict[str, Any]]
) -> None:
  template: Dict[str, Any] = rpc.call("personal", "getTransactionTemplate", req)
  if template["type"] != "Send":
    raise TestError("Template isn't of type Send.")
  if sortUTXOs(template["inputs"]) != sortUTXOs(inputs):
    raise TestError("Template inputs aren't as expected.")
  if template["outputs"] != outputs:
    raise TestError("Template outputs are incorrect.")

  keys: List[bytes] = []
  for inputJSON in template["inputs"]:
    key: bytes
    if inputJSON["change"]:
      key = getChangePublicKey(mnemonic, "", inputJSON["index"])
    else:
      key = getPublicKey(mnemonic, "", inputJSON["index"])
    if key not in keys:
      keys.append(key)

  if template["publicKey"] != Ristretto.aggregate([Ristretto.RistrettoPoint(key) for key in keys]).serialize().hex().upper():
    if len(keys) == 1:
      raise TestError("Template public key isn't correct when only a single key is present.")
    raise TestError("Public key aggregation isn't correct.")

#pylint: disable=too-many-statements
def WatchWalletTest(
  rpc: RPC
) -> None:
  #Keys to send funds to later.
  keys: List[bytes] = [
    Ristretto.SigningKey(i.to_bytes(1, "little") * 32).get_verifying_key() for i in range(5)
  ]

  #Backup the Mnemonic so we can independently derive this data and verify it.
  mnemonic: str = rpc.call("personal", "getMnemonic")

  #Node's Wallet's keys.
  nodeKeys: List[bytes] = [getPublicKey(mnemonic, "", i) for i in range(4)]
  nodeAddresses: List[str] = [getAddress(mnemonic, "", i) for i in range(4)]

  #Convert this to a WatchWallet node.
  account: Dict[str, Any] = rpc.call("personal", "getAccount")
  rpc.call("personal", "setAccount", account)
  if rpc.call("personal", "getAccount") != account:
    raise TestError("Meros set a different account.")

  #Verify it has the correct initial address.
  if rpc.call("personal", "getAddress") != nodeAddresses[0]:
    raise TestError("WatchWallet has an incorrect initial address.")

  #Load the vectors.
  #This test requires 3 Claims be available.
  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Personal/WatchWallet.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #The order of the Claims isn't relevant to this test.
  claims: List[Claim] = []
  for tx in transactions.txs.values():
    claims.append(Claim.fromTransaction(tx))

  def test() -> None:
    #Send to it.
    sends: List[bytes] = [createSend(rpc, claims[0], nodeKeys[0])]
    verify(rpc, sends[-1])

    #Test the most basic template possible.
    checkTemplate(
      rpc,
      mnemonic,
      {
        "outputs": [{
          "address": bech32_encode("mr", convertbits(bytes([0]) + keys[0], 8, 5), Encoding.BECH32M),
          "amount": "1"
        }]
      },
      [{
        "hash": sends[-1].hex().upper(),
        "nonce": 0,
        "change": False,
        "index": 0
      }],
      [
        {"key": keys[0].hex().upper(), "amount": "1"},
        {
          "key": getChangePublicKey(mnemonic, "", 0).hex().upper(),
          "amount": str(claims[0].amount - 1)
        }
      ]
    )

    #Verify it has the correct next address.
    if rpc.call("personal", "getAddress") != nodeAddresses[1]:
      raise TestError("WatchWallet has an incorrect next address.")

    #Send to it.
    sends.append(createSend(rpc, claims[1], nodeKeys[1]))
    verify(rpc, sends[-1])

    #Get and send to one more, yet don't verify it yet.
    if rpc.call("personal", "getAddress") != nodeAddresses[2]:
      raise TestError("WatchWallet has an incorrect next next address.")
    sends.append(createSend(rpc, claims[2], nodeKeys[2]))

    #Verify it can get UTXOs properly.
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(
      [
        {
          "address": getAddress(mnemonic, "", i),
          "hash": sends[i].hex().upper(),
          "nonce": 0
        } for i in range(2)
      ]
    ):
      raise TestError("WatchWallet Meros couldn't get its UTXOs.")

    #Also test balance getting.
    if rpc.call("personal", "getBalance") != str(
      sum(
        [
          int(
            rpc.call("transactions", "getTransaction", {"hash": send.hex()})["outputs"][0]["amount"]
          ) for send in sends[:2]
        ]
      )
    ):
      raise TestError("WatchWallet Meros couldn't get its balance.")

    #Verify the third Send.
    verify(rpc, sends[-1])

    #Close the sockets for now.
    rpc.meros.live.connection.close()
    rpc.meros.sync.connection.close()

    #Verify getUTXOs again. Redundant thanks to the extensive getUTXO testing elsewhere, yet valuable.
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(
      [
        {
          "address": getAddress(mnemonic, "", i),
          "hash": sends[i].hex().upper(),
          "nonce": 0
        } for i in range(3)
      ]
    ):
      raise TestError("WatchWallet Meros couldn't get its UTXOs.")

    #Again test the balance.
    if rpc.call("personal", "getBalance") != str(
      sum(
        [
          int(
            rpc.call("transactions", "getTransaction", {"hash": send.hex()})["outputs"][0]["amount"]
          ) for send in sends[:3]
        ]
      )
    ):
      raise TestError("WatchWallet Meros couldn't get its balance.")

    #Verify it can craft a Transaction Template properly.
    claimsAmount: int = sum(claim.amount for claim in claims)
    amounts: List[int] = [claimsAmount // 4, claimsAmount // 4, claimsAmount // 5]
    amounts.append(claimsAmount - sum(amounts))
    req: Dict[str, Any] = {
      "outputs": [
        {
          "address": bech32_encode("mr", convertbits(bytes([0]) + keys[0], 8, 5), Encoding.BECH32M),
          "amount": str(amounts[0])
        },
        {
          "address": bech32_encode("mr", convertbits(bytes([0]) + keys[1], 8, 5), Encoding.BECH32M),
          "amount": str(amounts[1])
        },
        {
          "address": bech32_encode("mr", convertbits(bytes([0]) + keys[2], 8, 5), Encoding.BECH32M),
          "amount": str(amounts[2])
        }
      ]
    }
    inputs: List[Dict[str, Any]] = [
      {
        "hash": sends[i].hex().upper(),
        "nonce": 0,
        "change": False,
        "index": i
      } for i in range(3)
    ]
    outputs: List[Dict[str, Any]] = [
      {
        "key": keys[i].hex().upper(),
        "amount": str(amounts[i])
      } for i in range(3)
    ] + [
      {
        "key": getChangePublicKey(mnemonic, "", 0).hex().upper(),
        "amount": str(amounts[-1])
      }
    ]
    checkTemplate(rpc, mnemonic, req, inputs, outputs)

    #Specify only to use specific addresses and verify Meros does so.
    req["from"] = [nodeAddresses[1], nodeAddresses[2]]

    #Correct the amounts so this is feasible.
    del req["outputs"][-1]
    del outputs[-2]
    #Remove the change output amount and actual output amount.
    for _ in range(2):
      del amounts[-1]
    claimsAmount -= claims[-1].amount
    #Correct the change output.
    outputs[-1]["amount"] = str(claimsAmount - sum(amounts))

    del inputs[0]
    checkTemplate(rpc, mnemonic, req, inputs, outputs)
    del req["from"]

    #Use the change address in question and verify the next template uses the next change address.
    #This is done via creating a Send which doesn't spend all of inputs value.
    #Also tests Meros handles Sends, and therefore templates, which don't use all funds.
    change: bytes = getChangePublicKey(mnemonic, "", 0)

    #Convert to a Wallet in order to do so.
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic})
    send: Dict[str, Any] = rpc.call(
      "transactions",
      "getTransaction",
      {
        "hash": rpc.call(
          "personal",
          "send",
          {
            "outputs": [
              {
                "address": bech32_encode("mr", convertbits(bytes([0]) + change, 8, 5), Encoding.BECH32M),
                "amount": "1"
              }
            ]
          }
        )
      }
    )
    #Convert back.
    rpc.call("personal", "setAccount", account)

    #Reconnect.
    sleep(65)
    rpc.meros.liveConnect(Blockchain().blocks[0].header.hash)
    rpc.meros.syncConnect(Blockchain().blocks[0].header.hash)

    #Verify the Send so the Wallet doesn't lose Meros from consideration.
    verify(rpc, bytes.fromhex(send["hash"]))

    #Verify the Send's accuracy.
    if len(send["inputs"]) != 1:
      raise TestError("Meros used more inputs than neccessary.")
    if send["outputs"] != [
      {"key": change.hex().upper(), "amount": "1"},
      #Uses the existing, unused, change address as change.
      #While this Transaction will make it used, that isn't detected.
      #This isn't worth programming around due to the lack of implications except potentially minor metadata.
      {"key": change.hex().upper(), "amount": str(claims[0].amount - 1)}
    ]:
      raise TestError("Send outputs weren't as expected.")

    if rpc.call("personal", "getTransactionTemplate", req)["outputs"][-1]["key"] != getChangePublicKey(mnemonic, "", 1).hex().upper():
      raise TestError("Meros didn't move to the next change address.")

    #Specify an explicit change address.
    req["change"] = nodeAddresses[3]
    if rpc.call("personal", "getTransactionTemplate", req)["outputs"][-1]["key"] != nodeKeys[3].hex().upper():
      raise TestError("Meros didn't handle an explicitly set change address.")

    #Verify RPC methods which require the private key error properly.
    #Tests via getMnemonic and data.
    try:
      rpc.call("personal", "getMnemonic")
      raise TestError()
    except Exception as e:
      if str(e) != "-3 This is a WatchWallet node; no Mnemonic is set.":
        raise TestError("getMnemonic didn't error as expected when Meros didn't have a Wallet.")

    try:
      rpc.call("personal", "data", {"data": "abc"})
      raise TestError()
    except Exception as e:
      if str(e) != "-3 This is a WatchWallet node; no Mnemonic is set.":
        raise TestError("data didn't error as expected when Meros didn't have a Wallet.")

    #Also test getMeritHolderKey, as no Merit Holder key should exist.
    try:
      rpc.call("personal", "getMeritHolderKey")
      raise TestError()
    except Exception as e:
      if str(e) != "-3 Node is running as a WatchWallet and has no Merit Holder.":
        raise TestError("data didn't error as expected when Meros didn't have a Wallet.")

    #Try calling getTransactionTemplate spending way too much Meros.
    try:
      rpc.call(
        "personal",
        "getTransactionTemplate",
        {
          "outputs": [
            {
              "address": bech32_encode("mr", convertbits(bytes([0]) + keys[0], 8, 5), Encoding.BECH32M),
              "amount": str(claimsAmount * 100)
            }
          ]
        }
      )
      raise TestError()
    except Exception as e:
      if str(e) != "1 Wallet doesn't have enough Meros.":
        raise TestError("Meros didn't error as expected when told to spend more Meros than it has.")

    #Try calling getTransactionTemplate with no outputs.
    try:
      rpc.call("personal", "getTransactionTemplate", {"outputs": []})
      raise TestError()
    except Exception as e:
      if str(e) != "-3 No outputs were provided.":
        raise TestError("Meros didn't error as expected when told to create a template with no outputs.")

    #Try calling getTransactionTemplate with a 0 value output.
    try:
      rpc.call(
        "personal",
        "getTransactionTemplate",
        {
          "outputs": [
            {
              "address": bech32_encode("mr", convertbits(bytes([0]) + keys[0], 8, 5), Encoding.BECH32M),
              "amount": "0"
            }
          ]
        }
      )
      raise TestError()
    except Exception as e:
      if str(e) != "-3 0 value output was provided.":
        raise TestError("Meros didn't error as expected when told to create a template with a 0 value output.")

  #Use a late enough block we can instantly verify transactions.
  Liver(rpc, vectors["blockchain"], transactions, {50: test}).live()
