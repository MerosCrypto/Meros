#Errors lib.
import ../../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Lattice lib.
import ../../../Database/Lattice/Lattice

#RPC object.
import ../objects/RPCObj

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
        "nonce": ntry.nonce,
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
            result["mintNonce"] = % $cast[Claim](entry).mintNonce
            result["bls"]       = % $cast[Claim](entry).bls
        of EntryType.Send:
            result["output"] = % cast[Send](entry).output
            result["amount"] = % $cast[Send](entry).amount
            result["proof"]  = % cast[Send](entry).proof
            result["argon"] = % $cast[Send](entry).argon
        of EntryType.Receive:
            result["index"] = %* {}
            result["index"]["key"] = % cast[Receive](entry).index.key
            result["index"]["nonce"]   = % cast[Receive](entry).index.nonce
        of EntryType.Data:
            result["data"]   = % cast[Data](entry).data.toHex()
            result["proof"]  = % cast[Data](entry).proof
            result["argon"] = % $cast[Data](entry).argon

#Get the height of an account.
proc getHeight(
    rpc: RPC,
    account: string
): JSONNode {.raises: [EventError].} =
    #Get the height.
    var height: int
    try:
        height = rpc.functions.lattice.getHeight(account)
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
        balance = rpc.functions.lattice.getBalance(account)
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
        entry = rpc.functions.lattice.getEntryByHash(hash)
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
        entry = rpc.functions.lattice.getEntryByIndex(
            newIndex(
                address,
                nonce
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
