#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Transactions lib.
import ../../../Database/Transactions/Transactions

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#String utils standard lib.
import strutils

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

    try:
        if not (tx of Mint):
            for input in tx.inputs:
                result["inputs"].add(%* {
                    "hash": $input.hash
                })

        if not (tx of Data):
            for output in tx.outputs:
                result["outputs"].add(%* {
                    "amount": $output.amount
                })
    except KeyError as e:
        doAssert(false, "Couldn't add inputs/outputs to input/output arrays we just created: " & e.msg)

    case tx:
        of Mint as mint:
            result["descendant"] = % "Mint"

            result["nonce"] = % mint.nonce
            try:
                result["outputs"][0]["key"] = % $cast[MintOutput](mint.outputs[0]).key
            except KeyError as e:
                doAssert(false, "Couldn't add a Mint's output's key to its output: " & e.msg)

        of Claim as claim:
            result["descendant"] = % "Claim"

            try:
                for o in 0 ..< claim.outputs.len:
                    result["outputs"][o]["key"] = % $cast[SendOutput](claim.outputs[o]).key
            except KeyError as e:
                doAssert(false, "Couldn't add a Claim's outputs' keys to its outputs: " & e.msg)

            result["signature"] = % $claim.signature

        of Send as send:
            result["descendant"] = % "Send"

            try:
                for i in 0 ..< send.inputs.len:
                    result["inputs"][i]["nonce"] = % cast[SendInput](send.inputs[i]).nonce
                for o in 0 ..< send.outputs.len:
                    result["outputs"][o]["key"] = % $cast[SendOutput](send.outputs[o]).key
            except KeyError as e:
                doAssert(false, "Couldn't add a Send's inputs' nonces/outputs' keys to its inputs/outputs: " & e.msg)

            result["signature"] = % $send.signature
            result["proof"] = % send.proof
            result["argon"] = % $send.argon

        of Data as data:
            result["descendant"] = % "Data"

            result["data"] = % data.data.toHex()

            result["signature"] = % $data.signature
            result["proof"] = % data.proof
            result["argon"] = % $data.argon

#Create the Transactions module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    try:
        newRPCFunctions:
            #Get Transaction by hash.
            "getTransaction" = proc (
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

                #Get the Transaction.
                try:
                    res["result"] = % functions.transactions.getTransaction(params[0].getStr().toHash(384))
                except IndexError:
                    raise newJSONRPCError(-2, "Transaction not found")
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid hash")

            #Get Transaction's Merit by hash.
            "getMerit" = proc (
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

                #Get the Transaction.
                try:
                    res["result"] = %* {
                        "merit": functions.transactions.getMerit(params[0].getStr().toHash(384))
                    }
                except IndexError:
                    raise newJSONRPCError(-2, "Transaction not found")
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid hash")
    except Exception as e:
        doAssert(false, "Couldn't create the Transactions Module: " & e.msg)
