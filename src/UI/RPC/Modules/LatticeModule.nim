#Errors lib.
import ../../../lib/Errors

#BN lib.
import BN

#BLS lib.
import ../../../lib/BLS

#Verification obj.
import ../../../Database/Merit/objects/VerificationsObj

#Lattice lib.
import ../../../Database/Lattice/Lattice

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#Finals lib.
import finals

#JSON standard lib.
import json

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

#Get unarchived verifications.
proc getUnarchivedVerifications(rpc: RPC): JSONNode {.raises: [EventError].} =
    var verifs: seq[MemoryVerification]
    try:
        verifs = rpc.events.get(
            proc (): seq[MemoryVerification],
            "lattice.getUnarchivedVerifications"
        )()
    except:
        raise newException(EventError, "Couldn't get and call lattice.getUnarchivedVerifications.")

    #Create the result array.
    result = %* []
    for verif in verifs:
        result.add(%* {
            "verifier": $verif.verifier,
            "hash": $verif.hash,
            "signature": $verif.signature
        })

#Handler.
proc `latticeModule`*(
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
            of "getHeight":
                res = rpc.getHeight(
                    json["args"][0].getStr()
                )

            of "getBalance":
                res = rpc.getBalance(
                    json["args"][0].getStr()
                )

            of "getUnarchivedVerifications":
                res = rpc.getUnarchivedVerifications()

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
