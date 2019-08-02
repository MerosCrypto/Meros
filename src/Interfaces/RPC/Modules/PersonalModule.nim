#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Transactions lib.
import ../../../Database/Transactions/Transactions

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Create the Personal module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    try:
        newRPCFunctions:
            #Set the Node's Wallet's Mnemonic.
            "setMnemonic" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify the params len.
                if params.len > 2:
                    raise newException(ParamError, "")
                #Verify the params' types.
                for param in params:
                    if param.kind != JString:
                        raise newException(ParamError, "")

                #Fill in optional params.
                while params.len < 2:
                    params.add(% "")

                #Create the Wallet.
                try:
                    functions.personal.setMnemonic(params[0].getStr(), params[1].getStr())
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid Mnemonic")

            #Get the Node's Wallet's Mnemonic.
            "getMnemonic" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                res["result"] = % functions.personal.getMnemonic().sentence

            #Create and publish a Send.
            "send" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify the params.
                if (
                    (params.len != 2) or
                    (params[0].kind != JString) or
                    (params[1].kind != JString)
                ):
                    raise newException(ParamError, "")

                try:
                    res["result"] = % $functions.personal.send(params[0].getStr(), params[1].getStr())
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid amount")
                except AddressError:
                    raise newJSONRPCError(-5, "Invalid address")
                except NotEnoughMeros:
                    raise newJSONRPCError(1, "Not enough Meros")

            #Create and publish a Data.
            "data" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify the params.
                if (
                    (params.len != 1) or
                    (params[0].kind != JString)
                ):
                    raise newException(ParamError, "")

                try:
                    res["result"] = % $functions.personal.data(params[0].getStr())
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid data length")
                except DataExists:
                    raise newJSONRPCError(0, "Data exists")

            #Convert a Public Key to an address.
            "toAddress" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify the params.
                if (
                    (params.len != 1) or
                    (params[0].kind != JString)
                ):
                    raise newException(ParamError, "")

                try:
                    res["result"] = % newAddress(params[0].getStr())
                except EdPublicKeyError:
                    raise newJSONRPCError(-3, "Invalid Public Key")
    except Exception as e:
        doAssert(false, "Couldn't create the Consensus Module: " & e.msg)
