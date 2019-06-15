#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/MinerWallet
import ../../../Wallet/Wallet

#Transactions lib.
import ../../../Database/Transactions/Transactions

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Get a transaction.
proc getTransaction*(
    rpc: RPC,
    hash: string
): JSONNode {.forceCheck: [].} =
    var tx: Transaction
    try:
        tx = rpc.functions.transactions.getTransaction(hash.toHash(384))
    except ValueError as e:
        return %* {
            "error": e.msg
        }
    except IndexError as e:
        return %* {
            "error": e.msg
        }

    result = %* {
        "descendant": $tx.descendant,
        "inputs": [],
        "outputs": [],
        "hash": $tx.hash,
        "verified": tx.verified
    }

    try:
        case tx.descendant:
            of TransactionType.Mint:
                for output in tx.outputs:
                    result["outputs"].add(%* {
                        "amount": output.amount.toBinary().toHex(),
                        "output": $cast[MintOutput](output).key
                    })

                result["nonce"] = % cast[Mint](tx).nonce

            of TransactionType.Claim:
                for input in tx.inputs:
                    result["inputs"].add(%* {
                        "hash": $input.hash
                    })
                for output in tx.outputs:
                    result["outputs"].add(%* {
                        "amount": output.amount.toBinary().toHex(),
                        "output": $cast[SendOutput](output).key
                    })

                result["signature"] = % $cast[Claim](tx).signature

            of TransactionType.Send:
                for input in tx.inputs:
                    result["inputs"].add(%* {
                        "hash": $input.hash,
                        "nonce": cast[SendInput](input).nonce
                    })
                for output in tx.outputs:
                    result["outputs"].add(%* {
                        "amount": output.amount.toBinary().toHex(),
                        "output": $cast[SendOutput](output).key
                    })

                var send: Send = cast[Send](tx)
                result["signature"] = % $send.signature
                result["proof"] = % send.proof
                result["argon"] = % $send.argon
    except KeyError as e:
        doAssert(false, "Couldn't append inputs/outputs: " & e.msg)

#Handler.
proc transactions*(
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
            of "getTransaction":
                if json["args"].len < 1:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.getTransaction(json["args"][0].getStr())

            else:
                reply(%* {
                    "error": "Invalid method."
                })
    except KeyError:
        res = %* {
            "error": "Missing `args`."
        }

    reply(res)
