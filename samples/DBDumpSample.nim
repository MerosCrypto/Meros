import strutils
import sets
import json

import asyncdispatch

import MerosRPC

var
  rpc: MerosRPC = waitFor newMerosRPC()
  db: JSONNode = %* {
    "blockchain": [],
    "transactions": {}
  }
  hashes: HashSet[string] = initHashSet[string]()

#Get every Block.
for nonce in 0 ..< waitFor rpc.merit.getHeight():
  db["blockchain"].add(waitFor rpc.merit.getBlock(nonce))

  #Get the matching Mint.
  try:
    db["transactions"][
      db["blockchain"][db["blockchain"].len - 1]["hash"].getStr()
    ] = waitFor rpc.transactions.getTransaction(
      parseHexStr(db["blockchain"][db["blockchain"].len - 1]["hash"].getStr())
    )
  #This will raise if there wasn't a Mint for this Block.
  except MerosError:
    discard

  #Mark every Transaction so we can grab them later.
  for tx in db["blockchain"][db["blockchain"].len - 1]["transactions"]:
    hashes.incl(parseHexStr(tx["hash"].getStr()))

#Get every Transaction.
for hash in hashes:
  db["transactions"][hash.toHex()] = waitFor rpc.transactions.getTransaction(hash)

#Write it to a file.
"data/db.json".writeFile(db.pretty(4))
