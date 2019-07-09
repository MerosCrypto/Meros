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
proc getUnarchivedRecords(
    rpc: RPC
): JSONNode {.forceCheck: [].} =
    #Get the records.
    var records: tuple[
        records: seq[MeritHolderRecord],
        aggregate: BLSSignature
    ] = rpc.functions.consensus.getUnarchivedRecords()

    #Create the JSON.
    result = %* {
        "records": [],
        "aggregate": $records.aggregate
    }

    #Add each record.
    for i in 0 ..< records.records.len:
        try:
            result["records"].add(%* {
                "holder":    $records.records[i].key,
                "nonce":     records.records[i].nonce,
                "merkle":    $records.records[i].merkle
            })
        except KeyError as e:
            doAssert(false, "Couldn't access the records value of a JSON object we just created with said field: " & e.msg)

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

            of "getUnarchivedRecords":
                res = rpc.getUnarchivedRecords()

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
