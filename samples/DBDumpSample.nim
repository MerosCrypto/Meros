#Ember RPC module.
import EmberRPC

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

var
    #RPC.
    rpc: EmberRPC = waitFor newEmberRPC()
    #DB.
    db: JSONNode = %* {
        "blockchain": [],
        "lattice": {}
    }
    #Amount of blocks.
    height: int = waitFor rpc.merit.getHeight()

#Get every Block.
for nonce in 0 ..< height:
    db["blockchain"].add(waitFor rpc.merit.getBlock(nonce))

#Get every Entry.
for syncBlock in db["blockchain"]:
    for verif in syncBlock["verifications"]:
        db["lattice"][verif["hash"].getStr()] = waitFor rpc.lattice.getEntryByHash(verif["hash"].getStr())

#Write it to a file.
"data/db.json".writeFile(db.pretty(4))
