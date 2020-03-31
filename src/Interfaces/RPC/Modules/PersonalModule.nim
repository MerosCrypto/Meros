#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Wallet libs.
import ../../../Wallet/Wallet
import ../../../Wallet/MinerWallet

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
            #Get the Node's MinerWallet's private key.
            "getMiner" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                res["result"] = % $functions.personal.getMinerWallet().privateKey

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
                    raise newLoggedException(ParamError, "")
                #Verify the params' types.
                for param in params:
                    if param.kind != JString:
                        raise newLoggedException(ParamError, "")

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
                res["result"] = % functions.personal.getWallet().mnemonic.sentence

            #Get an address from the Wallet.
            "getAddress" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Supply optional parameters.
                if params.len == 0:
                    params.add(% 0)
                if params.len == 1:
                    params.add(% false)

                #Verify the params.
                if (
                    (params.len != 2) or
                    (params[0].kind != JInt) or
                    (params[1].kind != JBool)
                ):
                    raise newLoggedException(ParamError, "")

                #Get the account in question.
                var wallet: HDWallet = functions.personal.getWallet()
                try:
                    wallet = wallet[uint32(params[0].getInt())]
                except ValueError:
                    raise newJSONRPCError(-3, "Unusable account")

                #Get the tree in question.
                try:
                    if params[1].getBool():
                        wallet = wallet.derive(1)
                    else:
                        wallet = wallet.derive(0)
                except ValueError as e:
                    panic("Unusable external/internal trees despite checking for their validity: " & e.msg)

                #Get the child.
                try:
                    res["result"] = % wallet.next().address
                except ValueError:
                    raise newJSONRPCError(-3, "Tree has no valid children")

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
                    raise newLoggedException(ParamError, "")

                try:
                    res["result"] = % $functions.personal.send(params[0].getStr(), params[1].getStr())
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid amount")
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
                    raise newLoggedException(ParamError, "")

                try:
                    res["result"] = % $functions.personal.data(params[0].getStr())
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid data length or missing datas")
                except DataExists:
                    raise newJSONRPCError(0, "Data exists")
    except Exception as e:
        panic("Couldn't create the Consensus Module: " & e.msg)
