#Errors lib.
import ../../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#BlS lib.
import ../../../lib/BLS

#Index object.
import ../../../Database/common/objects/IndexObj

#Verifications lib.
import ../../../Database/Verifications/Verifications

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#Block lib.
import ../../../Database/Merit/Block

#Message object.
import ../../../Network/objects/MessageObj

#ParseBlock lib.
import ../../../Network/Serialize/Merit/ParseBlock

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import mc_events

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

proc getHeight(rpc: RPC): JSONNode {.raises: [EventError].} =
    #Get the Height.
    var height: uint
    try:
        height = rpc.events.get(
            proc (): uint,
            "merit.getHeight"
        )()
    except:
        raise newException(EventError, "Couldn't get and call merit.getHeight.")

    #Send back the Height.
    result = %* {
        "height": int(height)
    }

proc getDifficulty(rpc: RPC): JSONnode {.raises: [EventError].} =
    #Get the Block Difficulty.
    var difficulty: BN
    try:
        difficulty = rpc.events.get(
            proc (): BN,
            "merit.getDifficulty"
        )()
    except:
        raise newException(EventError, "Couldn't get and call merit.getDifficulty.")

    #Send back the difficulty.
    result = %* {
        "difficulty": $difficulty
    }

proc getBlock(rpc: RPC, nonce: uint): JSONNode {.raises: [KeyError, EventError].} =
    #Get the Block.
    var gotBlock: Block
    try:
        gotBlock = rpc.events.get(
            proc (nonce: uint): Block,
            "merit.getBlock"
        )(nonce)
    except:
        raise newException(EventError, "Couldn't get and call merit.getBlock.")

    #Create the Block.
    result = %* {
        "header": {
            "nonce": int(gotBlock.header.nonce),
            "last": $gotBlock.header.last,

            "verifications": $gotBlock.header.verifications,
            "miners": $gotBlock.header.miners,

            "time": int(gotBlock.header.time),
            "proof": int(gotBlock.header.proof)
        },
        "hash": $gotBlock.hash
    }

    #Add the Verifications.
    result["verifications"] = %* []
    for index in gotBlock.verifications:
        result["verifications"].add(%* {
            "verifier": index.key.toHex(),
            "nonce": int(index.nonce)
        })

    #Add the Miners.
    result["miners"] = %* []
    for miner in gotBlock.miners:
        result["miners"].add(%* {
            "miner": $miner.miner,
            "amount": int(miner.amount)
        })

#Publish a Block.
proc publishBlock(rpc: RPC, data: string): Future[JSONNode] {.async.} =
    var success: bool = false
    try:
        if not await rpc.events.get(
            proc (newBlock: Block): Future[bool],
            "merit.block"
        )(data.parseBlock()):
            raise newException(Exception, "Failed to add the Block.")
        else:
            success = true
    except:
        raise newException(EventError, "Couldn't get and call merit.publishBlock.")

    #If that worked, broadcast the Block.
    if success:
        try:
            rpc.events.get(
                proc (msgType: MessageType, msg: string),
                "network.broadcast"
            )(MessageType.Block, data)
        except:
            echo "Failed to broadcast the Block."

#Handler.
proc meritModule*(
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
                res = rpc.getHeight()

            of "getDifficulty":
                res = rpc.getDifficulty()

            of "getBlock":
                res = rpc.getBlock(
                    uint(json["args"][0].getInt())
                )

            of "publishBlock":
                res = await rpc.publishBlock(
                    parseHexStr(json["args"][0].getStr())
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
