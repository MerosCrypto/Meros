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
    rpc: MerosRPC = waitFor newMerosRPC(port = 5135)
    #DB.
    db: JSONNode = %* {
        "verifications": {},
        "blockchain": [],
        "lattice": {}
    }
    #Amount of blocks.
    height: int = waitFor rpc.merit.getHeight()
    #List of Lattice Entries.
    hashes: seq[string] = @[]

#Get every Block.
for nonce in 0 ..< height:
    db["blockchain"].add(waitFor rpc.merit.getBlock(nonce))

#Get every Verification.
for syncBlock in db["blockchain"]:
    for verif in syncBlock["verifications"]:
        if not db["verifications"].hasKey(verif["verifier"].getStr()):
            db["verifications"][verif["verifier"].getStr()] = %* []

        for nonce in db["verifications"][verif["verifier"].getStr()].len .. verif["nonce"].getInt():
            var hash: JSONNode = (waitFor rpc.verifications.getVerification(verif["verifier"].getStr(), uint(nonce)))["hash"]
            db["verifications"][verif["verifier"].getStr()].add(
                hash
            )
            hashes.add(hash.getStr())

#Get every entry.
hashes = hashes.deduplicate()
for hash in hashes:
    db["lattice"][hash] = waitFor rpc.lattice.getEntryByHash(hash)

#Write it to a file.
"data/db.json".writeFile(db.pretty(4))
