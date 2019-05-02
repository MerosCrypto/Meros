#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Lattice lib.
import ../../../Database/Lattice/Lattice

#RPC object.
import ../objects/RPCObj

#BN lib.
import BN

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

proc toJSON*(
    entry: Entry
): JSONNode {.forceCheck: [].} =
    #Set the Entry's fields.
    result = %* {
        "descendant": $entry.descendant,
        "sender": entry.sender,
        "nonce": entry.nonce,
        "hash": $entry.hash,
        "signature": entry.signature.toHex(),
        "verified": entry.verified
    }

    #Set the descendant fields.
    case entry.descendant:
        of EntryType.Mint:
            result["output"] = % $cast[Mint](entry).output
            result["amount"] = % $cast[Mint](entry).amount
        of EntryType.Claim:
            result["mintNonce"] = % cast[Claim](entry).mintNonce
            result["bls"]       = % $cast[Claim](entry).bls
        of EntryType.Send:
            result["output"] = % cast[Send](entry).output
            result["amount"] = % $cast[Send](entry).amount
            result["proof"]  = % cast[Send](entry).proof
            result["argon"]  = % $cast[Send](entry).argon
        of EntryType.Receive:
            result["index"] = %* {
                "address": cast[Receive](entry).index.address,
                "nonce":   cast[Receive](entry).index.nonce
            }
        of EntryType.Data:
            result["data"]  = % cast[Data](entry).data.toHex()
            result["proof"] = % cast[Data](entry).proof
            result["argon"] = % $cast[Data](entry).argon

#Get the height of an account.
proc getHeight(
    rpc: RPC,
    account: string
): JSONNode {.forceCheck: [].} =
    #Get the height.
    var height: int
    try:
        height = rpc.functions.lattice.getHeight(account)
    except AddressError as e:
        returnError()

    #Send back the height.
    result = %* {
        "height": height
    }

#Get the balance of an account.
proc getBalance(
    rpc: RPC,
    account: string
): JSONNode {.forceCheck: [].} =
    #Get the balance.
    var balance: BN
    try:
        balance = rpc.functions.lattice.getBalance(account)
    except AddressError as e:
        returnError()

    #Send back the balance.
    result = %* {
        "balance": $balance
    }

#Get an Entry by its hash.
proc getEntryByHash(
    rpc: RPC,
    hash: Hash[384]
): JSONNode {.forceCheck: [].} =
    #Get the Entry.
    var entry: Entry
    try:
        entry = rpc.functions.lattice.getEntryByHash(hash)
    except IndexError as e:
        returnError()

    result = entry.toJSON()

#Get an Entry by its index.
proc getEntryByIndex(
    rpc: RPC,
    address: string,
    nonce: int
): JSONNode {.forceCheck: [].} =
    #Get the Entry.
    var entry: Entry
    try:
        entry = rpc.functions.lattice.getEntryByIndex(
            newLatticeIndex(
                address,
                nonce
            )
        )
    except ValueError as e:
        returnError()
    except IndexError as e:
        returnError()

    result = entry.toJSON()

#Handler.
proc lattice*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (
        json: JSONNode
    ) {.raises: [].}
) {.forceCheck: [], async.} =
    #Declare a var for the response.
    var res: JSONNode

    #Switch based off the method.
    var methodStr: string
    try:
        methodStr = json["method"].getStr()
    except KeyError:
        reply(%* {
            "error": "No method specified."
        })
        return

    try:
        case methodStr:
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
                    json["args"][0].getStr().toHash(384)
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
    except KeyError:
        res = %* {
            "error": "Missing `args`."
        }
    except ValueError:
        res = %* {
            "error": "Invalid hash passed to getEntryByHash."
        }
    except IndexError:
        res = %* {
            "error": "Not enough args were passed."
        }
    reply(res)
