#Errors lib.
import ../../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Lattice lib.
import ../../../Database/Lattice/Lattice

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import mc_events

#Finals lib.
import finals

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

proc toJSON*(
    entry: Entry
): JSONNode {.raises: [KeyError].} =
    #Set the Entry fields.
    result = %* {
        "descendant": $entry.descendant,
        "sender": entry.sender,
        "nonce": int(entry.nonce),
        "hash": $entry.hash,
        "signature": ($entry.signature).toHex(),
        "verified": entry.verified
    }

    #Set the descendant fields.
    case entry.descendant:
        of EntryType.Mint:
            result["output"] = % cast[Mint](entry).output.toHex()
            result["amount"] = % $cast[Mint](entry).amount
        of EntryType.Claim:
            result["mintNonce"] = % int(cast[Claim](entry).mintNonce)
            result["bls"]       = % $cast[Claim](entry).bls
        of EntryType.Send:
            result["output"] = % cast[Send](entry).output
            result["amount"] = % $cast[Send](entry).amount
            result["sha512"] = % $cast[Send](entry).sha512
            result["proof"]  = % int(cast[Send](entry).proof)
        of EntryType.Receive:
            result["index"] = %* {}
            result["index"]["key"] = % cast[Receive](entry).index.key
            result["index"]["nonce"]   = % int(cast[Receive](entry).index.nonce)
        of EntryType.Data:
            result["data"]   = % cast[Data](entry).data.toHex()
            result["sha512"] = % $cast[Data](entry).sha512
            result["proof"]  = % int(cast[Data](entry).proof)

#Get the height of an account.
proc getHeight(
    rpc: RPC,
    account: string
): JSONNode {.raises: [EventError].} =
    #Get the height.
    var height: uint
    try:
        height = rpc.events.get(
            proc (account: string): uint,
            "lattice.getHeight"
        )(account)
    except:
        raise newException(EventError, "Couldn't get and call lattice.getHeight.")

    #Send back the height.
    result = %* {
        "height": $height
    }

#Get the balance of an account.
proc getBalance(
    rpc: RPC,
    account: string
): JSONNode {.raises: [EventError].} =
    #Get the balance.
    var balance: BN
    try:
        balance = rpc.events.get(
            proc (account: string): BN,
            "lattice.getBalance"
        )(account)
    except:
        raise newException(EventError, "Couldn't get and call lattice.getBalance.")

    #Send back the balance.
    result = %* {
        "balance": $balance
    }

#Get an Entry by its hash.
proc getEntryByHash(
    rpc: RPC,
    hash: string
): JSONNode {.raises: [KeyError, EventError].} =
    #Get the Entry.
    var entry: Entry
    try:
        entry = rpc.events.get(
            proc (hash: string): Entry,
            "lattice.getEntryByHash"
        )(hash)
    except:
        raise newException(EventError, "Couldn't get and call lattice.getEntryByHash.")

    result = entry.toJSON()

#Get an Entry by its index.
proc getEntryByIndex(
    rpc: RPC,
    address: string,
    nonce: int
): JSONNode {.raises: [KeyError, EventError].} =
    #Get the Entry.
    var entry: Entry
    try:
        entry = rpc.events.get(
            proc (index: Index): Entry,
            "lattice.getEntryByIndex"
        )(
            newIndex(
                address,
                uint(nonce)
            )
        )
    except:
        raise newException(EventError, "Couldn't get and call lattice.getEntryByIndex.")

    result = entry.toJSON()

#Handler.
proc latticeModule*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.async.} =
    #Declare a var for the response.
    var res: JSONNode

    #Put this in a try/catch in case the method fails.
    try:
        #Switch based off the method.
        case json["method"].getStr():
            of "getHeight":
                res = rpc.getHeight(
                    json["args"][0].getStr()
                )

            of "getBalance":
                res = rpc.getBalance(
                    json["args"][0].getStr()
                )

            of "getEntryByHash":
                res = rpc.getEntryByHash(
                    json["args"][0].getStr().parseHexStr()
                )

            of "getEntryByIndex":
                res = rpc.getEntryByIndex(
                    json["args"][0].getStr(),
                    json["args"][1].getInt()
                )

            else:
                res = %* {
                    "error": "Invalid method."
                }
    except:
        #If there was an issue, make the response the error message.
        res = %* {
            "error": getCurrentExceptionMsg()
        }

    reply(res)
