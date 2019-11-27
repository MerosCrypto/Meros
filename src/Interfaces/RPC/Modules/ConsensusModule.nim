#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Consensus lib.
import ../../../Database/Consensus/Consensus

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Create the Consensus module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    try:
        newRPCFunctions:
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
                    raise newException(ParamError, "")

                #Extract the parameter.
                var hash: Hash[384]
                try:
                    hash = params[0].getStr().toHash(384)
                except ValueError:
                    raise newException(ParamError, "")

                #Get the Status.
                var status: TransactionStatus
                try:
                    status = functions.consensus.getStatus(hash)
                except IndexError:
                    raise newJSONRPCError(-2, "Transaction Status not found")

                #Get the verifiers and Merit.
                var
                    verifiers: JSONNode = % []
                    merit: int = status.merit
                if merit == -1:
                    merit = 0
                    for holder in status.holders.keys():
                        verifiers.add(% holder)
                        if not functions.consensus.isMalicious(holder):
                            merit += functions.merit.getMerit(holder)

                res["result"] = %* {
                    "verifiers":  verifiers,
                    "merit":      merit,
                    "threshold":  functions.consensus.getThreshold(status.epoch),
                    "verified":   status.verified,
                    "competing": status.competing,
                }
    except Exception as e:
        doAssert(false, "Couldn't create the Consensus Module: " & e.msg)
