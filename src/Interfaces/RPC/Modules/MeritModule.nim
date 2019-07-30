#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../Database/common/objects/MeritHolderRecordObj

#Merit lib.
import ../../../Database/Merit/Merit

#RPC object.
import ../objects/RPCObj

#Block -> JSON.
proc `%`(
    blockArg: Block
): JSONNode {.forceCheck: [].} =
    #Convert the header.
    result = %* {
        "header": {
            "hash":      $blockArg.header.hash,

            "nonce":     blockArg.header.nonce,
            "last":      $blockArg.header.last,

            "aggregate": $blockArg.header.aggregate,
            "miners":    $blockArg.header.miners,

            "time":      blockArg.header.time,
            "proof":     blockArg.header.proof
        }
    }

    #Add the Records.
    try:
        result["records"] = %* []
        for index in blockArg.records:
            result["records"].add(%* {
                "holder": $index.key,
                "nonce":  index.nonce,
                "merkle": $index.merkle
            })
    except KeyError as e:
        doAssert(false, "Couldn't add a Record to a Block's JSON representation despite declaring an array for the Records: " & e.msg)

    #Add the Miners.
    try:
        result["miners"] = %* []
        for miner in blockArg.miners.miners:
            result["miners"].add(%* {
                "miner":  $miner.miner,
                "amount": miner.amount
            })
    except KeyError as e:
        doAssert(false, "Couldn't add a Miner to a Block's JSON representation despite declaring an array for the Miners: " & e.msg)

#Create the RPC module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    newRPCFunctions:
        #Get Height.
        "getHeight" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [].} =
            res["result"] = % functions.merit.getHeight()

        #Get Difficulty.
        "getDifficulty" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [].} =
            res["result"] = % functions.merit.getDifficulty().difficulty.toString().toHex()

        #Get Block by nonce or hash.
        "getBlock" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError,
            RPCFunctionsError
        ].} =
            #Verify the parameters length.
            if params.len != 1:
                raise newException(ParamError)

            #Get the Block.
            if params[0].kind == JInt:
                try:
                    res["result"] = % functions.merit.getBlockByNonce(params[0].getInt())
                except IndexError as e:
                    raise newRPCFunctionsError(-1, "Block not found.", %* {
                        "height": functions.merit.getHeight()
                    })
            elif params[0].kind == JString:
                try:
                    res["result"] = % functions.merit.getBlockByHash(params[0].getString(),toHash(384))
                except IndexError as e:
                    raise newRPCFunctionsError(-1, "Block not found.")
            else:
                raise newException(ParamError)

        #Get Total Merit.
        "getTotalMerit" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [].} =
            res["result"] = % functions.merit.getTotalMerit()

        #Get Live Merit.
        "getLiveMerit" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [].} =
            res["result"] = % functions.merit.getLiveMerit()

        #Get a MeritHolder's Merit.
        "getMerit" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            ParamError
        ].} =
            #Verify the parameters length.
            if (
                (params.len != 1) or
                (params]0].kind != JString)
            ):
                raise newException(ParamError)

            #Extract the parameters.
            var key: BLSPublicKey
            try:
                key = newBLSPublicKey(params[0].getStr())
            except BLSError:
                raise newException(ParamError)

            res["result"] = % functions.merit.getMerit(key)

        "getBlockTemplate" = proc (
            res: var JSONNode,
            params: JSONNode
        ) {.forceCheck: [
            JSONRPCError
        ].} =
            #Verify and extract the parameters.
            if params.len == 0:
                raise newException(ParamError)

            var
                minersSeq: seq[Miner] = newSeq[Miner](params.len)
                miners: Miners
            for p in 0 ..< params.len:
                if (
                    (params[p].kind != JObject) or
                    (not params[p].hasKey("miner")) or
                    (params[p]["miner"].kind != JString) or
                    (not params[p].hasKey("amount")) or
                    (params[p]["amount"].kind != JString)
                ):
                    raise newException(ParamError)

                minersSeq[p] = newMinerObj(
                    newBLSPublicKey(params[p]["miner"].getStr()),
                    params[p]["amount"].getInt()
                )
            miners = newMinersObj(minersSeq)

            #Get the records.
            var records: tuple[
                records: seq[MeritHolderRecord],
                aggregate: BLSSignature
            ] = functions.consensus.getUnarchivedRecords()

            #Create the Header.
            result = %* {
                "header": newBlockHeader(
                    functions.merit.getHeight(),
                    functions.merit.getBlockByNonce(functions.merit.getHeight() - 1),
                    records.aggregate,
                    miners.merkle.hash,
                    getTime(),
                    0
                ).serializeHash(),
                
                "body": newBlockBody(
                    records.records,
                    miners
                ).serialize()
            }

        "publishBlock" = proc (
            res: var JSONNode,
            params: JSONNode
        ): Future[void] {.forceCheck: [
            JSONRPCError
        ], async.} =
            var newBlock: Block
            try:
                newBlock = data.parseBlock()
            except ValueError as e:
                raise newJSONRPCError(-2, e.msg)
            except ArgonError as e:
                raise newJSONRPCError(-2, e.msg)
            except BLSError as e:
                raise newJSONRPCError(-2, e.msg)

            try:
                await rpc.functions.merit.addBlock(newBlock)
            except ValueError as e:
                raise newJSONRPCError(-3, e.msg)
            except IndexError as e:
                raise newJSONRPCError(-3, e.msg)
            except GapError as e:
                raise newJSONRPCError(-3, e.msg)
            except DataExists as e:
                raise newJSONRPCError(-4, e.msg)
            except Exception as e:
                doAssert(false, "addBlock threw a raw Exception, despite catching all Exception types it naturally raises: " & e.msg)
