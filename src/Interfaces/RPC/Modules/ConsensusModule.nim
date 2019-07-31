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
        of SendDifficulty as sd:
            result["descendant"] = % "SendDifficulty"
            result["difficulty"] = % $sd.difficulty
        of DataDifficulty as dd:
            result["descendant"] = % "DataDifficulty"
            result["difficulty"] = % $dd.difficulty
        of GasPrice as gp:
            result["descendant"] = % "GasPrice"
            result["price"] = % gp.price
        of MeritRemoval as mr:
            result["descendant"] = % "MeritRemoval"
            result["elements"] = %* [
                %element1,
                %element2
            ]

#Create the Consensus module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    newRPCFunctions:
        #Get Element by key/nonce.
        "getElement" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            #Verify the parameters.
            if (
                (params.len != 2) or
                (params[0].kind != JString) or
                (params[1].kind != JInt)
            ):
                raise newException(ParamError)

            #Extract the parameters.
            var
                key: BLSPublicKey
                nonce: int = params[1].getInt()

            try:
                key = newBLSPublicKey(params[0].getStr())
            except BLSError:
                raise newException(ParamError)

            if nonce < 0:
                raise newException(ParamError)

            #Get the Element.
            try:
                res["result"] = %rpc.functions.consensus.getElement(key, nonce)
            except IndexError as e:
                raise newJSONRPCError(-1, "Element not found.", %* {
                    "height": functions.consensus.getHeight(key)
                })

    discard """
        "publishSignedVerification" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            discard

        "publishSignedSendDifficulty" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            discard

        "publishSignedDataDifficulty" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            discard

        "publishSignedGasPrice" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            discard

        "publishSignedMeritRemoval" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            discard
    """
