import strutils
import tables

import ../../../lib/[Errors, Util, Hash]
import ../../../lib/Sketcher as SketcherFile
import ../../../Wallet/MinerWallet

import ../../../objects/GlobalFunctionBoxObj

import ../../../Database/Consensus/Elements/Elements

import ../../../Database/Merit/Merit

import ../../../Network/objects/SketchyBlockObj

import ../../../Network/Serialize/SerializeCommon
import ../../../Network/Serialize/Merit/[
  SerializeBlockHeader,
  SerializeBlockBody,
  ParseBlock
]

import ../objects/RPCObj

#Element -> JSON.
#This wouldn't work with %, broke everything with %*, so now we have this symbol.
proc `%**`(
  elem: Element
): JSONNode {.forceCheck: [].} =
  result = %* {}

  case elem:
    of Verification as verif:
      result["descendant"] = % "Verification"

      result["hash"] = % $verif.hash

    of SendDifficulty as sendDiff:
      result["descendant"] = % "SendDifficulty"

      result["holder"] = % sendDiff.holder
      result["nonce"] = % sendDiff.nonce
      result["difficulty"] = % sendDiff.difficulty

    of DataDifficulty as dataDiff:
      result["descendant"] = % "DataDifficulty"

      result["holder"] = % dataDiff.holder
      result["nonce"] = % dataDiff.nonce
      result["difficulty"] = % dataDiff.difficulty

    of MeritRemovalVerificationPacket as packet:
      result["descendant"] = % "VerificationPacket"

      result["hash"] = % $packet.hash
      result["holders"] = % []
      for holder in packet.holders:
        try:
          result["holders"].add(% $holder)
        except KeyError as e:
          panic("Couldn't add a holder to a VerificationPacket's JSON representation despite declaring an array for the holders: " & e.msg)

    of MeritRemoval as mr:
      result["descendant"] = % "MeritRemoval"

      result["holder"] = % mr.holder
      result["partial"] = % mr.partial

      var
        element1: JSONNode = %** mr.element1
        element2: JSONNode = %** mr.element2

      if element1.hasKey("holder"):
        try:
          element1.delete("holder")
        except KeyError as e:
          panic("Couldn't delete a key we confirmed was present: " & e.msg)
      if element2.hasKey("holder"):
        try:
          element2.delete("holder")
        except KeyError as e:
          panic("Couldn't delete a key we confirmed was present: " & e.msg)

      result["elements"] = % [element1, element2]

    else:
      panic("MeritModule's `%`(Element) passed an unsupported Element type.")

#Block -> JSON.
proc `%`(
  blockArg: Block
): JSONNode {.forceCheck: [].} =
  #Add the hash, header, and aggregate signature.
  result = %* {
    "hash":   $blockArg.header.hash,
    "header": {
      "version":   blockArg.header.version,
      "last":    $blockArg.header.last,
      "contents":  $blockArg.header.contents,

      "significant":  blockArg.header.significant,
      "sketchSalt":   blockArg.header.sketchSalt.toHex(),
      "sketchCheck":  $blockArg.header.sketchCheck,

      "time":    blockArg.header.time,
      "proof":   blockArg.header.proof,
      "signature": $blockArg.header.signature
    },
    "aggregate": $blockArg.body.aggregate
  }

  #Add the miner to the header.
  try:
    if blockArg.header.newMiner:
      result["header"]["miner"] = % $blockArg.header.minerKey
    else:
      result["header"]["miner"] = % blockArg.header.minerNick
  except KeyError as e:
    panic("Couldn't add a miner to a BlockHeader's JSON representation despite declaring an object for the header: " & e.msg)

  #Add the Packets.
  result["transactions"] = % []
  try:
    for packet in blockArg.body.packets:
      result["transactions"].add(%* {
        "hash": $packet.hash,
        "holders": packet.holders
      })
  except KeyError as e:
    panic("Couldn't add a Transaction hash to a Block's JSON representation despite declaring an array for the hashes: " & e.msg)

  #Add the Elements.
  result["elements"] = % []
  try:
    for elem in blockArg.body.elements:
      result["elements"].add(%** elem)
  except KeyError as e:
    panic("Couldn't add an Element to a Block's JSON representation despite declaring an array for the Elements: " & e.msg)

proc module*(
  functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
  #Table of usable Sketcher objects.
  #Shared between the getBlockTemplate/publishBlock routes.
  var sketchers: Table[int, Sketcher] = initTable[int, Sketcher]()

  try:
    newRPCFunctions:
      "getHeight" = proc (
        res: JSONNode,
        params: JSONNode
      ) {.forceCheck: [].} =
        res["result"] = % functions.merit.getHeight()

      "getDifficulty" = proc (
        res: JSONNode,
        params: JSONNode
      ) {.forceCheck: [].} =
        res["result"] = % functions.merit.getDifficulty().toHex()

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
            var strHash: string = parseHexStr(params[0].getStr())
            if strHash.len != 32:
              raise newJSONRPCError(-3, "Invalid hash")
            res["result"] = % functions.merit.getBlockByHash(strHash.toHash[:256]())
          except IndexError:
            raise newJSONRPCError(-2, "Block not found")
          except ValueError:
            raise newJSONRPCError(-3, "Invalid hash")
        else:
          raise newException(ParamError, "")

      "getTotalMerit" = proc (
        res: JSONNode,
        params: JSONNode
      ) {.forceCheck: [].} =
        res["result"] = % functions.merit.getTotalMerit()

      "getUnlockedMerit" = proc (
        res: JSONNode,
        params: JSONNode
      ) {.forceCheck: [].} =
        res["result"] = % functions.merit.getUnlockedMerit()

      "getMerit" = proc (
        res: JSONNode,
        params: JSONNode
      ) {.forceCheck: [
        ParamError
      ].} =
        #Verify the parameters length.
        if (
          (params.len != 1) or
          (params[0].kind != JInt) or
          (params[0].getInt() >= 65536)
        ):
          raise newException(ParamError, "")

        #Extract the parameter.
        var nick: uint16 = uint16(params[0].getInt())

        #Create the result.
        res["result"] = %* {
          "status": if functions.merit.isUnlocked(nick): "Unlocked" elif functions.merit.isPending(nick): "Pending" else: "Locked",
          "malicious": functions.consensus.isMalicious(nick),
          "merit": functions.merit.getRawMerit(nick)
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
          miner = newBLSPublicKey(params[0].getStr().parseHexStr())
        except ValueError:
          raise newJSONRPCError(-3, "Invalid miner")
        except BLSError:
          raise newJSONRPCError(-4, "Invalid miner")

        var
          #Pending packets/elements.
          pending: tuple[
            packets: seq[VerificationPacket],
            elements: seq[BlockElement],
            aggregate: BLSSignature
          ] = functions.consensus.getPending()

          #ID for this Sketcher.
          id: int = sketchers.len
          #Sketch salt we're using with the packets.
          sketchSaltNum: uint32 = 0
          #Actual sketch salt.
          sketchSalt: string

        #Verify the packets don't collide with our salt.
        while true:
          try:
            sketchers[id] = newSketcher(
              (
                proc (
                  nick: uint16
                ): int {.raises: [].} =
                  functions.merit.getMerit(nick, functions.merit.getHeight())
              ),
              functions.consensus.isMalicious,
              pending.packets
            )

            sketchSalt = sketchSaltNum.toBinary(INT_LEN)
            if not sketchers[id].collides(sketchSalt):
              break
            inc(sketchSaltNum)
          except KeyError as e:
            panic("Couldn't get a Sketcher we just created: " & e.msg)

        #Delete the sketcher from 5 templates ago.
        sketchers.del(id - 5)

        #Create the Header.
        var
          contents: tuple[packets: Hash[256], contents: Hash[256]] = newContents(pending.packets, pending.elements)
          header: JSONNode = newJNull()
        try:
          var nick: uint16
          try:
            nick = functions.merit.getNickname(miner)
          except IndexError:
            header = % newBlockHeader(
              0,
              functions.merit.getTail(),
              contents.contents,
              1,
              sketchSalt,
              newSketchCheck(sketchSalt, pending.packets),
              miner,
              getTime(),
              0,
              newBLSSignature()
            ).serializeTemplate().toHex()

          if header.kind == JNull:
            header = % newBlockHeader(
              0,
              functions.merit.getTail(),
              contents.contents,
              1,
              sketchSalt,
              newSketchCheck(sketchSalt, pending.packets),
              nick,
              getTime(),
              0,
              newBLSSignature()
            ).serializeTemplate().toHex()
        except IndexError as e:
          panic("Couldn't get the Block with a nonce one lower than the height: " & e.msg)
        except BLSError:
          panic("Couldn't create a temporary signature for a BlockHeader template.")

        #Create the result.
        try:
          res["result"] = %* {
            "id": id,
            "key":  functions.merit.getRandomXCacheKey().toHex(),
            "header": header,
            "body": newBlockBodyObj(
              contents.packets,
              pending.packets,
              pending.elements,
              pending.aggregate
            ).serialize(sketchSalt, pending.packets.len).toHex()
          }
        except ValueError as e:
          panic("Block Body had sketch collision: " & e.msg)

      "publishBlock" = proc (
        res: JSONNode,
        params: JSONNode
      ): Future[void] {.forceCheck: [
        ParamError,
        JSONRPCError
      ], async.} =
        #Verify the parameters.
        if (
          (params.len != 2) or
          (params[0].kind != JInt) or
          (params[1].kind != JString)
        ):
          raise newException(ParamError, "")

        var sketchyBlock: SketchyBlock
        try:
          sketchyBlock = functions.merit.getRandomX().parseBlock(params[1].getStr().parseHexStr())
        except ValueError:
          raise newJSONRPCError(-3, "Invalid Block")

        #Test the Block Header.
        try:
          functions.merit.testBlockHeader(sketchyBlock.data.header)
        except ValueError:
          raise newJSONRPCError(-3, "Invalid Block")

        try:
          await functions.merit.addBlock(
            sketchyBlock,
            sketchers[params[0].getInt()],
            false
          )
        except KeyError:
          raise newJSONRPCError(-2, "Invalid ID")
        except ValueError:
          raise newJSONRPCError(-3, "Invalid Block")
        except DataMissing:
          raise newJSONRPCError(-1, "Missing Block-referenced data")
        except Exception as e:
          panic("addBlock threw a raw Exception, despite catching all Exception types it naturally raises: " & e.msg)
  except Exception as e:
    panic("Couldn't create the Merit Module: " & e.msg)
