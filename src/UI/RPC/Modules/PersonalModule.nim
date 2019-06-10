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

#Message object.
import ../../../Network/objects/MessageObj

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Set the Wallet's secret.
proc setSecret(
    rpc: RPC,
    secret: string
): JSONNode {.forceCheck: [].} =
    try:
        rpc.functions.personal.setSecret(secret)
    except ValueError as e:
        returnError()
    except RandomError as e:
        doAssert(secret.len == 0, "personal.setSecret threw a RandomError despite being passed a secret: " & e.msg)
        returnError()

#Get the Wallet info.
proc getWallet(
    rpc: RPC
): JSONNode {.forceCheck: [].} =
    var wallet: Wallet = rpc.functions.personal.getWallet()
    if not wallet.initiated:
        return %* {
            "error": "Personal does not have a Wallet."
        }

    result = %* {
        "privateKey": $wallet.privateKey,
        "publicKey": $wallet.publicKey,
        "address": wallet.address
    }

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
            of "setSecret":
                if json["args"].len < 1:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.setSecret(json["args"][0].getStr())

            of "getWallet":
                res = rpc.getWallet()

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
