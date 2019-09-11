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

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Element -> JSON.
proc `%`(
    elem: Element
): JSONNode {.forceCheck: [].} =
    result = %* {
        "holder": $elem.holder,
        "nonce": elem.nonce
    }

    case elem:
        of Verification as verif:
            result["descendant"] = % "Verification"
            result["hash"] = % $verif.hash
        of MeritRemoval as mr:
            result["descendant"] = % "MeritRemoval"
            result["partial"] = % mr.partial
            result["elements"] = %* [
                % mr.element1,
                % mr.element2
            ]

#Create the Consensus module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    try:
        newRPCFunctions:
            #Get Merit Holder's height.
            "getHeight" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError
            ].} =
                #Verify the parameters.
                if (
                    (params.len != 1) or
                    (params[0].kind != JString)
                ):
                    raise newException(ParamError, "")

                #Extract the parameter.
                var key: BLSPublicKey
                try:
                    key = newBLSPublicKey(params[0].getStr())
                except BLSError:
                    raise newException(ParamError, "")

                #Get the height.
                res["result"] = % functions.consensus.getHeight(key)

            #Get Element by key/nonce.
            "getElement" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify the parameters.
                if (
                    (params.len != 2) or
                    (params[0].kind != JString) or
                    (params[1].kind != JInt)
                ):
                    raise newException(ParamError, "")

                #Extract the parameters.
                var
                    key: BLSPublicKey
                    nonce: int = params[1].getInt()

                try:
                    key = newBLSPublicKey(params[0].getStr())
                except BLSError:
                    raise newException(ParamError, "")

                if nonce < 0:
                    raise newException(ParamError, "")

                #Get the Element.
                try:
                    res["result"] = % functions.consensus.getElement(key, nonce)
                except IndexError:
                    raise newJSONRPCError(-2, "Element not found", %* {
                        "height": functions.consensus.getHeight(key)
                    })

            "getStatus" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify the parameters.
                if (
                    (params.len != 1) or
                    (params[0].kind != JString)
                ):
                    raise newException(ParamError, "")

                #Extract the parameter.
                var hash: Hash[384]
                try:
                    hash = params[0].getStr().toHash(384)
                except ValueError:
                    raise newException(ParamError, "")

                #Get the Status, Merit, and create the result.
                try:
                    var
                        status: TransactionStatus = functions.consensus.getStatus(hash)
                        merit: int = status.merit
                    if merit == -1:
                        merit = 0
                        for verifier in status.verifiers:
                            if not functions.consensus.isMalicious(verifier):
                                merit += functions.merit.getMerit(verifier)

                    res["result"] = %* {
                        "merit":      merit,
                        "threshold":  functions.consensus.getThreshold(status.epoch),
                        "verified":   status.verified,
                        "defaulting": status.defaulting,
                    }
                except IndexError:
                    raise newJSONRPCError(-2, "Transaction Status not found")
    except Exception as e:
        doAssert(false, "Couldn't create the Consensus Module: " & e.msg)
