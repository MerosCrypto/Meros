#Errors lib.
import ../../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#VerifierIndex object.
import ../../../Database/Merit/objects/VerifierIndexObj

#Verifications lib.
import ../../../Database/Verifications/Verifications

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#Finals lib.
import finals

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Get unarchived verifications.
proc getUnarchivedVerifications(
    rpc: RPC
): JSONNode {.raises: [EventError].} =
    #Get the indexes.
    var indexes: seq[VerifierIndex]
    try:
        indexes = rpc.events.get(
            proc (): seq[VerifierIndex],
            "verifications.getUnarchivedIndexes"
        )()
    except:
        raise newException(EventError, "Couldn't get and call verifications.getUnarchivedIndexes.")

    #Get the aggregates.
    var aggregates: seq[BLSSignature] = newSeq[BLSSignature](indexes.len)
    for i in 0 ..< indexes.len:
        try:
            aggregates[i] = rpc.events.get(
                proc (
                    verifier: string,
                    nonce: uint
                ): BLSSignature, "verifications.getPendingAggregate"
            )(
                indexes[i].key,
                indexes[i].nonce
            )
        except:
            raise newException(EventError, "Couldn't get and call verifications.getPendingAggregate.")

    #Create the JSON.
    result = %* []
    #Add each index/merkle.
    for i in 0 ..< indexes.len:
        result.add(%* {
            "verifier": indexes[i].key.toHex(),
            "nonce": int(indexes[i].nonce),
            "merkle": indexes[i].merkle.toHex(),
            "signature": $aggregates[i]
        })

#Handler.
proc verificationsModule*(
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
