#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#JSON standard lib.
import json

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

#Handler.
proc `meritModule`*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.raises: [].} =
    #Declare a var for the response.
    var res: JSONNode

    #Put this in a try/catch in case the method fails.
    try:
        #Switch based off the method.
        case json["method"].getStr():
            of "getDifficulty":
                res = rpc.getDifficulty()

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
