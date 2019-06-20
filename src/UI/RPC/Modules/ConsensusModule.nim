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
    var elem:  Element
    try:
        elem = rpc.functions.consensus.getElement(key, nonce)
    except IndexError as e:
        returnError()

    result = %* {
        "holder": $elem.holder,
        "nonce": elem.nonce
    }
    case elem:
        of Verification as verif:
            result["descendant"] = %"verification"
            result["hash"] = %($verif.hash)
        else:
            doAssert(false, "Element should be a Verification.")

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
            "holder":    $records[i].key,
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
                if json["args"].len < 2:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.getElement(
                        newBLSPublicKey(json["args"][0].getStr()),
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
    except BLSError:
        res = %* {
            "error": "Invalid BLS Public Key."
        }

    reply(res)
