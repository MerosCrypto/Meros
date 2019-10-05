#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

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

#String utils standard lib.
import strutils

#Element -> JSON.
proc `%`(
    elem: Element
): JSONNode {.forceCheck: [].} =
    result = %* {
        "holder": elem.holder
    }

    case elem:
        of Verification as verif:
            result["hash"] = $verif.hash

        of MeritRemovalVerificationPacket as packet:
            result["hash"] = $packet.hash
            result["holders"] = % []
            for holder in packet.holders:
                try:
                    result["holders"].add($ holder)
                except KeyError as e:
                    doAssert(false, "Couldn't add a holder to a VerificationPacket's JSON representation despite declaring an array for the holders: " & e.msg)

        of MeritRemoval as mr:
            result["descendent"] = % "MeritRemoval"
            result["partial"] = % mr.partial
            result["elements"] = %* [
                mr.element1,
                mr.element2
            ]

        else:
            doAssert(false, "MeritModule's `%`(Element) passed an unsupported Element type.")

#Block -> JSON.
proc `%`(
    blockArg: Block
): JSONNode {.forceCheck: [].} =
    #Add the hash, header, and aggregate signature.
    result = %* {
        "hash":   $blockArg.header.hash,
        "header": {
            "version":   blockArg.header.version,
            "last":      $blockArg.header.last,

            "contents":  $blockArg.header.contents,
            "verifiers": $blockArg.header.verifiers,

            "miner":     $blockArg.header.miner,
            "time":      blockArg.header.time,
            "proof":     blockArg.header.proof,
            "signature": $blockArg.header.signature
        },
        "aggregate": $blockArg.body.aggregate
    }

    #Add the Transactions.
    result["transactions"] = % []
    try:
        for tx in blockArg.body.transactions:
            result["transactions"].add(% $tx)
    except KeyError as e:
        doAssert(false, "Couldn't add a Transaction hash to a Block's JSON representation despite declaring an array for the hashes: " & e.msg)

    #Add the Elements.
    result["elements"] = % []
    try:
        for elem in blockArg.body.elements:
            result["elements"].add(% elem)
    except KeyError as e:
        doAssert(false, "Couldn't add an Element to a Block's JSON representation despite declaring an array for the Elements: " & e.msg)

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
                #Verify and extract the parameter.
                if (params.len != 1) or (params[0].kind != JString):
                    raise newException(ParamError, "")

                var miner: BLSPublicKey
                try:
                    miner = newBLSPublicKey(params[0].getStr())
                except BLSError:
                    raise newJSONRPCError(-4, "Invalid miner")

                #Create the Header.
                var header: JSONNode = nil
                try:
                    var nick: int
                    try:
                        nick = functions.merit.getNickname(miner)
                    except IndexError as e:
                        header == % newBlockHeader(
                            0,
                            functions.merit.getBlockByNonce(functions.merit.getHeight() - 1).hash,
                            Hash[384](),
                            Hash[384](),
                            miner,
                            getTime()
                        ).serializeHash().toHex()

                    if header != nil:
                        header == % newBlockHeader(
                            0,
                            functions.merit.getBlockByNonce(functions.merit.getHeight() - 1).hash,
                            Hash[384](),
                            Hash[384](),
                            nick,
                            getTime()
                        ).serializeHash().toHex()
                except IndexError as e:
                    doAssert(false, "Couldn't get the Block with a nonce one lower than the height: " & e.msg)

                #Create the result.
                res["result"] = %* {
                    "header": header,
                    "body": newBlockBodyObj(@[], @[]).serialize().toHex()
                }

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
                    newBlock = params[0].getStr().parseHexStr().parseBlock()
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
