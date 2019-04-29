#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Hex lib.
import ../../../lib/Hex

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verifications lib.
import ../../../Database/Verifications/Verifications

#Merit lib.
import ../../../Database/Merit/Merit

#Parse Block lib.
import ../../../Network/Serialize/Merit/ParseBlock

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

proc getHeight(
    rpc: RPC
): JSONNode {.forceCheck: [].} =
    result = %* {
        "height": rpc.functions.merit.getHeight()
    }

proc getDifficulty(
    rpc: RPC
): JSONnode {.forceCheck: [].} =
    result = %* {
        "difficulty": rpc.functions.merit.getDifficulty().difficulty.toHex()
    }

proc getBlock(
    rpc: RPC,
    nonce: int
): JSONNode {.forceCheck: [].} =
    #Get the Block.
    var gotBlock: Block
    try:
        gotBlock = rpc.functions.merit.getBlock(nonce)
    except IndexError as e:
        returnError()

    #Create the Block.
    result = %* {
        "header": {
            "hash":      $gotBlock.header.hash,

            "nonce":     gotBlock.header.nonce,
            "last":      $gotBlock.header.last,

            "aggregate": $gotBlock.header.aggregate,
            "miners":    $gotBlock.header.miners,

            "time":      gotBlock.header.time,
            "proof":     gotBlock.header.proof
        }
    }

    #Add the Records.
    try:
        result["records"] = %* []
        for index in gotBlock.records:
            result["records"].add(%* {
                "verifier": $index.key,
                "nonce":    index.nonce,
                "merkle":   $index.merkle
            })
    except KeyError as e:
        doAssert(false, "Couldn't add a Record to a Block's JSON representation despite declaring an array for the Records: " & e.msg)

    #Add the Miners.
    try:
        result["miners"] = %* []
        for miner in gotBlock.miners.miners:
            result["miners"].add(%* {
                "miner":  $miner.miner,
                "amount": miner.amount
            })
    except KeyError as e:
        doAssert(false, "Couldn't add a Miner to a Block's JSON representation despite declaring an array for the Miners: " & e.msg)

#Publish a Block.
#This proc doesn't use returnError as the async macro occurs before the returnError macro.
#The async macro is also the reason for `res`.
proc publishBlock(
    rpc: RPC,
    data: string
): Future[JSONNode] {.forceCheck: [], async.} =
    var newBlock: Block

    try:
        newBlock = data.parseBlock()
    except ValueError as e:
        return %* {
            "error": e.msg
        }
    except ArgonError as e:
        return %* {
            "error": e.msg
        }
    except BLSError as e:
        return %* {
            "error": e.msg
        }

    try:
        await rpc.functions.merit.addBlock(newBlock)
    except ValueError as e:
        echo "Failed to add the Block due to a ValueError: " & e.msg
        return %* {
            "error": e.msg
        }
    except IndexError as e:
        echo "Failed to add the Block due to a IndexError: " & e.msg
        return %* {
            "error": e.msg
        }
    except GapError as e:
        echo "Failed to add the Block due to a GapError: " & e.msg
        return %* {
            "error": e.msg
        }
    except DataExists as e:
        echo "Failed to add the Block due to DataExists: " & e.msg
        return %* {
            "error": e.msg
        }
    except Exception as e:
        doAssert(false, "addBlock threw a raw Exception, despite catching all Exception types it naturally raises: " & e.msg)

#Handler.
proc merit*(
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
                res = rpc.getHeight()

            of "getDifficulty":
                res = rpc.getDifficulty()

            of "getBlock":
                res = rpc.getBlock(
                    json["args"][0].getInt()
                )

            of "publishBlock":
                try:
                    res = await rpc.publishBlock(
                        json["args"][0].getStr().parseHexStr()
                    )
                except Exception as e:
                    doAssert(false, "publishBlock threw an Exception despite not naturally throwing anything: " & e.msg)

            else:
                res = %* {
                    "error": "Invalid method."
                }
    except ValueError:
        res = %* {
            "error": "Invalid hex string passed."
        }
    except KeyError:
        res = %* {
            "error": "Missing `args`."
        }

    reply(res)
