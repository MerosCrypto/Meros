#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../Database/common/objects/MeritHolderRecordObj

#Consensus lib.
import ../../../Database/Consensus/Consensus

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Get a Verification.
proc getElement(
    rpc: RPC,
    key: BLSPublicKey,
    nonce: int
): JSONnode {.forceCheck: [].} =
    try:
        result = %* {
            "hash": $rpc.functions.consensus.getElement(key, nonce).hash
        }
    except IndexError as e:
        returnError()

#Get unarchived Merit Holder Records.
proc getUnarchivedMeritHolderRecords(
    rpc: RPC
): JSONNode {.forceCheck: [].} =
    #Get the records.
    var records: seq[MeritHolderRecord] = rpc.functions.consensus.getUnarchivedRecords()

    #Get the aggregates.
    var aggregates: seq[BLSSignature] = newSeq[BLSSignature](records.len)
    for i in 0 ..< records.len:
        try:
            aggregates[i] = rpc.functions.consensus.getPendingAggregate(
                records[i].key,
                records[i].nonce
            )
        except IndexError as e:
            returnError()
        except BLSError as e:
            returnError()

    #Create the JSON.
    result = %* []
    #Add each index/merkle.
    for i in 0 ..< records.len:
        result.add(%* {
            "holder":  $records[i].key,
            "nonce":     records[i].nonce,
            "merkle":    $records[i].merkle,
            "signature": $aggregates[i]
        })

#Handler.
proc consensus*(
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
            of "getElement":
                var key: BLSPublicKey = newBLSPublicKey(json["args"][0].getStr())

                res = rpc.getElement(
                    key,
                    json["args"][1].getInt()
                )

            of "getUnarchivedMeritHolderRecords":
                res = rpc.getUnarchivedMeritHolderRecords()

            else:
                res = %* {
                    "error": "Invalid method."
                }
    except KeyError:
        res = %* {
            "error": "Missing `args`."
        }
    except IndexError:
        res = %* {
            "error": "Not enough args were passed."
        }
    except BLSError:
        res = %* {
            "error": "Invalid BLS Public Key."
        }

    reply(res)
