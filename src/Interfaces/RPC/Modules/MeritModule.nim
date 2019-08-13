#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../Database/common/objects/MeritHolderRecordObj

#Merit lib.
import ../../../Database/Merit/Merit

#Block Serialization libs.
import ../../../Network/Serialize/Merit/SerializeBlockHeader
import ../../../Network/Serialize/Merit/SerializeBlockBody
import ../../../Network/Serialize/Merit/ParseBlock

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#StInt lib.
import StInt

#String utils standard lib.
import strutils

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

#Create the Merit module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    try:
        newRPCFunctions:
            #Get Height.
            "getHeight" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                res["result"] = % functions.merit.getHeight()

            #Get Difficulty.
            "getDifficulty" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                try:
                    var
                        diffA: array[64, uint8] = functions.merit.getDifficulty().difficulty.toByteArrayBE()
                        diffStr: string = newString(48)
                    copyMem(addr diffStr[0], addr diffA[16], 48)
                    res["result"] = % diffStr.toHex()
                except DivByZeroError as e:
                    doAssert(false, "Serializing the difficulty threw an error: " & e.msg)

            #Get Block by nonce or hash.
            "getBlock" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify the parameters length.
                if params.len != 1:
                    raise newException(ParamError, "")

                #Get the Block.
                if params[0].kind == JInt:
                    try:
                        res["result"] = % functions.merit.getBlockByNonce(params[0].getInt())
                    except IndexError:
                        raise newJSONRPCError(-2, "Block not found", %* {
                            "height": functions.merit.getHeight()
                        })
                elif params[0].kind == JString:
                    try:
                        res["result"] = % functions.merit.getBlockByHash(params[0].getStr().toHash(384))
                    except IndexError:
                        raise newJSONRPCError(-2, "Block not found")
                    except ValueError:
                        raise newJSONRPCError(-3, "Invalid hash")
                else:
                    raise newException(ParamError, "")

            #Get Total Merit.
            "getTotalMerit" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                res["result"] = % functions.merit.getTotalMerit()

            #Get Live Merit.
            "getLiveMerit" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [].} =
                res["result"] = % functions.merit.getLiveMerit()

            #Get a MeritHolder's Merit.
            "getMerit" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError
            ].} =
                #Verify the parameters length.
                if (
                    (params.len != 1) or
                    (params[0].kind != JString)
                ):
                    raise newException(ParamError, "")

                #Extract the parameters.
                var key: BLSPublicKey
                try:
                    key = newBLSPublicKey(params[0].getStr())
                except BLSError:
                    raise newException(ParamError, "")

                res["result"] = %* {
                    "live": functions.merit.isLive(key),
                    "malicious": functions.consensus.isMalicious(key),
                    "merit": functions.merit.getMerit(key)
                }

            "getBlockTemplate" = proc (
                res: JSONNode,
                params: JSONNode
            ) {.forceCheck: [
                ParamError,
                JSONRPCError
            ].} =
                #Verify and extract the parameters.
                if params.len == 0:
                    raise newException(ParamError, "")

                var
                    minersSeq: seq[Miner] = newSeq[Miner](params.len)
                    miners: Miners
                for p in 0 ..< params.len:
                    try:
                        if (
                            (params[p].kind != JObject) or
                            (not params[p].hasKey("miner")) or
                            (params[p]["miner"].kind != JString) or
                            (not params[p].hasKey("amount")) or
                            (params[p]["amount"].kind != JInt)
                        ):
                            raise newException(ParamError, "")

                        minersSeq[p] = newMinerObj(
                            newBLSPublicKey(params[p]["miner"].getStr()),
                            params[p]["amount"].getInt()
                        )
                    except BLSError:
                        raise newJSONRPCError(-4, "Invalid miner")
                    except KeyError as e:
                        doAssert(false, "Couldn't get a Miner's miner/amount despite verifying their existence: " & e.msg)
                miners = newMinersObj(minersSeq)

                #Get the records.
                var records: tuple[
                    records: seq[MeritHolderRecord],
                    aggregate: BLSSignature
                ] = functions.consensus.getUnarchivedRecords()

                #Create the Header.
                try:
                    res["result"] = %* {
                        "header": newBlockHeader(
                            functions.merit.getHeight(),
                            functions.merit.getBlockByNonce(functions.merit.getHeight() - 1).hash,
                            records.aggregate,
                            miners.merkle.hash,
                            getTime(),
                            0
                        ).serializeHash().toHex(),

                        "body": newBlockBodyObj(
                            records.records,
                            miners
                        ).serialize().toHex()
                    }
                except IndexError as e:
                    doAssert(false, "Couldn't get the Block with a nonce one lower than the height: " & e.msg)

            "publishBlock" = proc (
                res: JSONNode,
                params: JSONNode
            ): Future[void] {.forceCheck: [
                ParamError,
                JSONRPCError
            ], async.} =
                #Verify the parameters.
                if (
                    (params.len != 1) or
                    (params[0].kind != JString)
                ):
                    raise newException(ParamError, "")

                var newBlock: Block
                try:
                    newBlock = parseBlock(parseHexStr(params[0].getStr()))
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid Block")
                except BLSError:
                    raise newJSONRPCError(-4, "Invalid BLS data")

                try:
                    await functions.merit.addBlock(newBlock)
                except ValueError:
                    raise newJSONRPCError(-3, "Invalid Block")
                except IndexError:
                    raise newJSONRPCError(-2, "Invalid/missing Records")
                except GapError:
                    raise newJSONRPCError(-1, "Missing previous Block")
                except DataExists:
                    raise newJSONRPCError(0, "Block already exists")
                except Exception as e:
                    doAssert(false, "addBlock threw a raw Exception, despite catching all Exception types it naturally raises: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't create the Merit Module: " & e.msg)
