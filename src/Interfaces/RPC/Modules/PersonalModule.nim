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

#RPC object.
import ../objects/RPCObj

#Create the Personal module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    newRPCFunctions:
        #Set the Node's Wallet's Mnemonic.
        "setMnemonic" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [].} =
            #Verify the params len.
            if params.len > 2:
                raise Exception(ParamError)
            #Verify the params' types.
            for param in params:
                if param.kind != JString:
                    raise newException(ParamError)

            #Fill in optional params.
            while params.len < 2:
                params.add(% "")

            #Create the Wallet.
            try:
                functions.personal.setWallet(params[0],getString(), params[1].getString())
            except ValueError as e:
                raise newJSONRPCError(-3, "Mnemnoic is either invalid or failed to generate a valid seed.", %* {
                    "msg": e.msg
                })

            res["result"] = % true

        #Get the Node's Wallet's Mnemonic.
        "getMnemonic" = proc (
            res: var JSONNode,
            params: JSONNode
        ): {.forceCheck: [].} =
            res["result"] = functions.personal.getWallet().mnemonic.sentence

        #Create and publish a Send.
        "send" = proc (
            res: var JSONNode,
            params: JSONNode
        ): {.forceCheck: [].} =
            #Verify the params.
            if (
                (params.len != 2) or
                (params[0].kind != JString) or
                (params[1].kind != JString)
            ):
                raise Exception(ParamError)

            try:
                res["result"] = % $rpc.functions.personal.send(destination, amount)
            except ValueError as e:
                raise newJSONRPCError(-3, e.msg)
            except AddressError as e:
                raise newJSONRPCError(-5, e.msg)
            except NotEnoughMeros as e:
                raise newJSONRPCError(1, e.msg)

        #Create and publish a Data.
        "data" = proc (
            res: var JSONNode,
            params: JSONNode
        ): {.forceCheck: [].} =
            #Verify the params.
            if (
                (params.len != 1) or
                (params[0].kind != JString)
            ):
                raise Exception(ParamError)

            try:
                res["result"] = % $rpc.functions.personal.data(data)
            except ValueError as e:
                raise newJSONRPCError(-3, e.msg)
            except DataExists as e:
                raise newJSONRPCError(0, e.msg)

        #Convert a Public Key to an address.
        "toAddress" = proc (
            res: var JSONNode,
            params: JSONNode
        ): {.forceCheck: [].} =
            #Verify the params.
            if (
                (params.len != 1) or
                (params[0].kind != JString)
            ):
                raise Exception(ParamError)

            try:
                res["result"] = % newAddress(params[0])
            except EdPublicKeyError as e:
                raise newJSONRPCError(-3, e.msg)
