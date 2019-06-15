#Meros RPC module.
import MerosRPC

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Seq utils standard lib.
import sequtils

var
    #RPC.
    rpc: MerosRPC = waitFor newMerosRPC()
    #DB.
    db: JSONNode = %* {
        "consensus": {},
        "blockchain": [],
        "transactions": {}
    }
    #List of Transactions Entries.
    hashes: seq[string] = @[]

#Get every Block.
for nonce in 0 ..< waitFor rpc.merit.getHeight():
    db["blockchain"].add(waitFor rpc.merit.getBlock(nonce))

#Get every Verification.
for syncBlock in db["blockchain"]:
    for record in syncBlock["records"]:
        if not db["consensus"].hasKey(record["holder"].getStr()):
            db["consensus"][record["holder"].getStr()] = %* []

        for nonce in db["consensus"][record["holder"].getStr()].len .. record["nonce"].getInt():
            var hash: JSONNode = (waitFor rpc.consensus.getElement(record["holder"].getStr(), nonce))["hash"]
            db["consensus"][record["holder"].getStr()].add(
                hash
            )
            hashes.add(hash.getStr())

#Get every Transaction.
hashes = hashes.deduplicate()
for hash in hashes:
    db["transactions"][hash] = waitFor rpc.transactions.getTransaction(hash)

#Write it to a file.
"data/db.json".writeFile(db.pretty(4))
