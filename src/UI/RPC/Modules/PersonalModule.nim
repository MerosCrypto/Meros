#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Transactions lib.
import ../../../Database/Transactions/Transactions

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Set the Wallet's seed.
proc setSeed(
    rpc: RPC,
    seed: string
): JSONNode {.forceCheck: [].} =
    try:
        rpc.functions.personal.setSeed(seed, "")
    except ValueError as e:
        returnError()

#Get the Wallet info.
proc getWallet(
    rpc: RPC
): JSONNode {.forceCheck: [].} =
    var wallet: Wallet = rpc.functions.personal.getWallet()
    if wallet.isNil:
        return %* {
            "error": "Personal does not have a Wallet."
        }

    result = %* {
        "seed": wallet.mnemonic.sentence,
        "address": wallet.address
    }

#Create a Send Transaction.
proc send(
    rpc: RPC,
    destination: string,
    amount: string
): JSONNode {.forceCheck: [].} =
    try:
        result = %* {
            "hash": $rpc.functions.personal.send(destination, amount)
        }
    except ValueError as e:
        returnError()
    except AddressError as e:
        returnError()
    except NotEnoughMeros as e:
        returnError()
    except DataExists as e:
        returnError()

#Create a Data Transaction.
proc data(
    rpc: RPC,
    data: string
): JSONNode {.forceCheck: [].} =
    try:
        result = %* {
            "hash": $rpc.functions.personal.data(data)
        }
    except ValueError as e:
        returnError()
    except DataExists as e:
        returnError()

#Handler.
proc personal*(
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
            of "setSeed":
                if json["args"].len < 1:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.setSeed(json["args"][0].getStr())

            of "getWallet":
                res = rpc.getWallet()

            of "send":
                if json["args"].len < 2:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.send(json["args"][0].getStr(), json["args"][1].getStr())

            of "data":
                if json["args"].len < 1:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.data(json["args"][0].getStr().parseHexStr())

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
            "error": "Invalid hex string passed."
        }

    reply(res)
