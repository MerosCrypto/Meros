#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Transactions lib.
import ../../../Database/Transactions/Transactions

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Transaction -> JSON.
proc `%`(
    tx: Transaction
): JSONNode {.forceCheck: [].} =
    result = %* {
        "inputs": [],
        "outputs": [],
        "hash": $tx.hash,
        "verified": tx.verified
    }

    if not tx of Mint:
        for input in tx:
            result["inputs"].add(%* {
                "hash": $input.hash
            })

    if not tx of Data:
        for output in tx:
            result["outputs"].add(%* {
                "amount": $output.amount
            })

    case tx:
        of Mint as mint:
            result["descendant"] = % "Mint"
            result["nonce"] = % mint.nonce

            result["outputs"][0]["key"] = % $cast[MintOutput](claim.outputs[0]).key

        of Claim as claim:
            result["descendant"] = % "Claim"
            result["signature"] = % $claim.signature

            for o in 0 ..< claim.outputs.len:
                result["outputs"][o]["key"] = % $cast[SendOutput](claim.outputs[o]).key

        of Send as send:
            result["descendant"] = % "Send"
            result["signature"] = % $send.signature
            result["proof"] = % send.proof
            result["argon"] = % $send.argon

            for i in 0 ..< send.inputs.len:
                result["inputs"][i]["amount"] = % $cast[SendInput](send.inputs[i]).amount
            for o in 0 ..< send.outputs.len:
                result["outputs"][o]["key"] = % $cast[SendOutput](send.outputs[o]).key

        of Data as data:
            result["descendant"] = % "Data"
            result["signature"] = % $data.signature
            result["proof"] = % data.proof
            result["argon"] = % $data.argon

#Create the Transactions module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    newRPCFunctions:
        #Get Transaction by key/nonce.
        "getTransaction" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            #Verify the parameters.
            if (
                (params.len != 1) or
                (params[0].kind != JString)
            ):
                raise newException(ParamError)

            #Get the Transaction.
            try:
                res["result"] = % rpc.functions.transactions.getTransaction(params[0].getString().toHash(384))
            except IndexError as e:
                raise newJSONRPCError(-2, "Transaction not found.")
            except ValueError as e:
                raise newJSONRPCError(-2, "Transaction not found.")
