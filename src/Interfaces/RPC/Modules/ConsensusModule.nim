#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Consensus lib.
import ../../../Database/Consensus/Consensus

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Sets standard lib.
import sets

#Create the Consensus module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    try:
        newRPCFunctions:
            #Get a Send Difficulty.
            "getSendDifficulty" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                res["result"] = % $functions.consensus.getSendDifficulty()

            #Get a Data Difficulty.
            "getDataDifficulty" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                res["result"] = % $functions.consensus.getDataDifficulty()

            #Get a Transaction's Status.
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
                    raise newLoggedException(ParamError, "")

                #Extract the parameter.
                var hash: Hash[256]
                try:
                    hash = params[0].getStr().toHash(256)
                except ValueError:
                    raise newLoggedException(ParamError, "")

                #Get the Status.
                var status: TransactionStatus
                try:
                    status = functions.consensus.getStatus(hash)
                except IndexError:
                    raise newJSONRPCError(-2, "Transaction Status not found")

                #Get the verifiers and Merit.
                var
                    verifiers: JSONNode = % []
                    merit: int = max(status.merit, 0)
                for holder in status.holders:
                    verifiers.add(% holder)
                    if (status.merit == -1) and (not functions.consensus.isMalicious(holder)):
                        merit += functions.merit.getMerit(holder, status.epoch)

                res["result"] = %* {
                    "verifiers":  verifiers,
                    "merit":      merit,
                    "threshold":  functions.consensus.getThreshold(status.epoch),
                    "verified":   status.verified,
                    "competing":  status.competing
                }
    except Exception as e:
        panic("Couldn't create the Consensus Module: " & e.msg)
