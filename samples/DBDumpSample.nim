#Meros RPC module.
import MerosRPC

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#JSON standard lib.
import json

var
    #RPC.
    rpc: MerosRPC = waitFor newMerosRPC()
    #DB.
    db: JSONNode = %* {
        "blockchain": [],
        "transactions": {}
    }
    #Table of Transactions.
    hashes: HashSet[string] = initHashSet[string]()

#Get every Block.
for nonce in 0 ..< waitFor rpc.merit.getHeight():
    db["blockchain"].add(waitFor rpc.merit.getBlock(nonce))
    for tx in db["blockchain"][db["blockchain"].len - 1]["transactions"]:
        hashes.incl(parseHexStr(tx["hash"].getStr()))

#Get every Transaction.
for hash in hashes:
    db["transactions"][hash.toHex()] = waitFor rpc.transactions.getTransaction(hash)

#Write it to a file.
"data/db.json".writeFile(db.pretty(4))
