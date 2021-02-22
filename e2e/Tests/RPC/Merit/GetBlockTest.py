from typing import Callable, Dict, List, Any
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Data, Transactions

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-statements
def GetBlockTest(
  rpc: RPC
) -> None:
  blockchain: Blockchain
  claim: Claim
  send: Send
  datas: List[Data]

  txKey: Callable[[Dict[str, Any]], str] = lambda tx: tx["hash"]

  def verify() -> None:
    for b in range(len(blockchain.blocks)):
      block: Dict[str, Any] = rpc.call("merit", "getBlock", {"block": blockchain.blocks[b].header.hash.hex().upper()})
      if rpc.call("merit", "getBlock", {"block": b}) != block:
        raise TestError("Meros reported different Blocks depending on if nonce/hash indexing.")

      #Python doesn't keep track of the removals.
      #That said, they should all be empty except for the last one.
      if b != (len(blockchain.blocks) - 1):
        if block["removals"] != []:
          raise TestError("Meros reported the Block had removals.")
      del block["removals"]

      if blockchain.blocks[b].toJSON() != block:
        raise TestError("Meros's JSON serialization of Blocks differs from Python's.")

    #Test the key serialization of the first Block.
    #The final Block uses a nick, hence the value in this.
    if rpc.call("merit", "getBlock", {"block": 1})["header"]["miner"] != PrivateKey(0).toPublicKey().serialize().hex().upper():
      raise TestError("Meros didn't serialize a miner's key properly.")

    #Manually test the final, and most complex, block.
    final: Dict[str, Any] = rpc.call("merit", "getBlock", {"block": len(blockchain.blocks) - 1})
    final["transactions"].sort(key=txKey)
    final["removals"].sort()
    if final != {
      "hash": blockchain.blocks[-1].header.hash.hex().upper(),

      "header": {
        "version":     blockchain.blocks[-1].header.version,
        "last":        blockchain.blocks[-1].header.last.hex().upper(),
        "contents":    blockchain.blocks[-1].header.contents.hex().upper(),
        "packets":     blockchain.blocks[-1].header.packetsQuantity,
        "sketchSalt":  blockchain.blocks[-1].header.sketchSalt.hex().upper(),
        "sketchCheck": blockchain.blocks[-1].header.sketchCheck.hex().upper(),
        "miner":       blockchain.blocks[-1].header.minerKey.hex().upper() if blockchain.blocks[-1].header.newMiner else blockchain.blocks[-1].header.minerNick,
        "time":        blockchain.blocks[-1].header.time,
        "proof":       blockchain.blocks[-1].header.proof,
        "signature":   blockchain.blocks[-1].header.signature.hex().upper()
      },

      "transactions": sorted(
        [
          {
            "hash": claim.hash.hex().upper(),
            "holders": [0]
          },
          {
            "hash": send.hash.hex().upper(),
            "holders": [0, 1, 2]
          },
          {
            "hash": datas[0].hash.hex().upper(),
            "holders": [0, 2]
          },
          {
            "hash": datas[1].hash.hex().upper(),
            "holders": [0, 1, 3]
          },
          {
            "hash": datas[2].hash.hex().upper(),
            "holders": [0, 1, 2, 3, 4]
          },
          {
            "hash": datas[3].hash.hex().upper(),
            "holders": [0, 1, 2, 3]
          }
        ],
        key=txKey
      ),

      "elements": [
        {
          "descendant": "DataDifficulty",
          "holder": 3,
          "nonce": 0,
          "difficulty": 8
        },
        {
          "descendant": "SendDifficulty",
          "holder": 0,
          "nonce": 0,
          "difficulty": 1
        },
        {
          "descendant": "DataDifficulty",
          "holder": 3,
          "nonce": 0,
          "difficulty": 4
        },
        {
          "descendant": "DataDifficulty",
          "holder": 4,
          "nonce": 2,
          "difficulty": 1
        },
        {
          "descendant": "SendDifficulty",
          "holder": 4,
          "nonce": 1,
          "difficulty": 3
        },
        {
          "descendant": "SendDifficulty",
          "holder": 2,
          "nonce": 1,
          "difficulty": 2
        },
        {
          "descendant": "DataDifficulty",
          "holder": 0,
          "nonce": 0,
          "difficulty": 7
        },
      ],

      "removals": [0, 3],

      "aggregate": blockchain.blocks[-1].body.aggregate.serialize().hex().upper()
    }:
      raise TestError("Final Block wasn't correct.")

    #Test invalid calls.
    try:
      rpc.call("merit", "getBlock", {"block": 100})
      raise Exception("")
    except Exception as e:
      if str(e) != "-2 Block not found.":
        raise TestError("getBlock didn't error when we used a non-existent nonce.")

    try:
      rpc.call("merit", "getBlock", {"block": -5})
      raise Exception("")
    except Exception as e:
      if str(e) != "-32602 Invalid params.":
        raise TestError("getBlock didn't error when we used a negative (signed) integer for a nonce.")

    try:
      rpc.call("merit", "getBlock", {"block": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"})
      raise Exception("")
    except Exception as e:
      if str(e) != "-2 Block not found.":
        raise TestError("getBlock didn't error when we used a non-existent hash.")

    try:
      rpc.call("merit", "getBlock", {"block": ""})
      raise Exception("")
    except Exception as e:
      if str(e) != "-32602 Invalid params.":
        raise TestError("getBlock didn't error when we used an invalid hash.")

  with open("e2e/Vectors/RPC/Merit/GetBlock.json", "r") as file:
    vectors: Dict[str, Any] = json.loads(file.read())
    blockchain = Blockchain.fromJSON(vectors["blockchain"])
    claim = Claim.fromJSON(vectors["claim"])
    send = Send.fromJSON(vectors["send"])
    datas = [Data.fromJSON(data) for data in vectors["datas"]]
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])
    Liver(rpc, vectors["blockchain"], transactions, {(len(blockchain.blocks) - 1): verify}).live()
