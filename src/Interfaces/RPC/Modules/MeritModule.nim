import strutils
import tables
import json

import chronos

import ../../../lib/[Errors, Util, Hash]
import ../../../lib/Sketcher
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

#BlockTemplate object, storing the info needed to create a template and publish a Block based off of one.
type BlockTemplate = object
  sketchSalt: string
  packets: seq[VerificationPacket]
  body: string
  contents: tuple[packets: Hash[256], contents: Hash[256]]

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
      "version":     blockArg.header.version,
      "last":        $blockArg.header.last,
      "contents":    $blockArg.header.contents,

      "packets":     blockArg.header.packetsQuantity,
      "sketchSalt":  blockArg.header.sketchSalt.toHex(),
      "sketchCheck": $blockArg.header.sketchCheck,

      "time":        blockArg.header.time,
      "proof":       blockArg.header.proof,
      "signature":   $blockArg.header.signature
    },
    "aggregate":     $blockArg.body.aggregate
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

  #Add the removals.
  result["removals"] = % []
  try:
    for holder in blockArg.body.removals:
      result["removals"].add(% holder)
  except KeyError as e:
    panic("Couldn't add a removal to a Block's JSON representation despite declaring an array for the removals: " & e.msg)

proc module*(
  functions: GlobalFunctionBox
): RPCHandle {.forceCheck: [].} =
  var
    templates: Table[uint32, BlockTemplate]
    lastTailUsedForTemplate: Hash[256] = Hash[256]()

  try:
    result = newRPCHandle:
      proc getHeight(): int {.forceCheck: [].} =
        functions.merit.getHeight()

      proc getDifficulty(): int {.forceCheck: [].} =
        int(functions.merit.getDifficulty())

      proc getBlock(
        block_JSON: JSONNode
      ): JSONNode {.forceCheck: [
        ParamError,
        JSONRPCError
      ].} =
        if block_JSON.kind == JInt:
          try:
            #Ensure this is within uint boundaries, raising a ParamError if not.
            discard retrieveFromJSON(block_JSON, uint)
            result = % functions.merit.getBlockByNonce(retrieveFromJSON(block_JSON, int))
          except ParamError as e:
            raise e
          except JSONRPCError as e:
            panic("getBlock's retrieveFromJSON (int) call caused a JSONRPCError, when it shouldn't call any of those paths: " & e.msg)
          except IndexError:
            raise newJSONRPCError(IndexError, "Block not found", %* {
              "height": functions.merit.getHeight()
            })

        else:
          try:
            result = % functions.merit.getBlockByHash(retrieveFromJSON(block_JSON, Hash[256]))
          except ParamError as e:
            raise e
          except JSONRPCError as e:
            panic("getBlock's retrieveFromJSON (Hash[256]) call caused a JSONRPCError, when it shouldn't call any of those paths: " & e.msg)
          except IndexError:
            raise newJSONRPCError(IndexError, "Block not found")

      proc getPublicKey(
        holder: uint16
      ): string {.forceCheck: [
        JSONRPCError
      ].} =
        try:
          result = $ functions.merit.getPublicKey(holder)
        except IndexError:
          raise newJSONRPCError(IndexError, "Nickname doesn't exist")

      proc getNickname(
        key: BLSPublicKey
      ): uint16 {.forceCheck: [
        JSONRPCError
      ].} =
        try:
          result = functions.merit.getNickname(key)
        except IndexError:
          raise newJSONRPCError(IndexError, "Key doesn't have a nickname assigned")

      proc getTotalMerit(): int {.forceCheck: [].} =
        functions.merit.getTotalMerit()

      proc getUnlockedMerit(): int {.forceCheck: [].} =
        functions.merit.getUnlockedMerit()

      proc getMerit(
        nick: uint16
      ): JSONNode {.forceCheck: [].} =
        result = %* {
          "status": if functions.merit.isUnlocked(nick): "Unlocked" elif functions.merit.isPending(nick): "Pending" else: "Locked",
          "malicious": functions.consensus.isMalicious(nick),
          "merit": functions.merit.getRawMerit(nick)
        }

      proc getBlockTemplate(
        miner: BLSPublicKey
      ): JSONNode {.forceCheck: [].} =
        let tail: Hash[256] = functions.merit.getTail()
        if lastTailUsedForTemplate != tail:
          templates = initTable[uint32, BlockTemplate]()
          lastTailusedForTemplate = tail

        #Create a new template if needed, as determined by our second-accuracy.
        #If we already created a template for this second, just use it (see https://github.com/MerosCrypto/Meros/issues/278).
        var
          time: uint32 = getTime()
          blockTemplate: BlockTemplate
        if not templates.hasKey(time):
          var
            pending: tuple[
              packets: seq[VerificationPacket],
              elements: seq[BlockElement],
              aggregate: BLSSignature
            ] = functions.consensus.getPending()
            sketchSalt: string = newString(4)

          #Create the new template.
          blockTemplate = BlockTemplate(
            packets: pending.packets,
            contents: newContents(pending.packets, pending.elements),
            body: ""
          )

          #Randomize the sketch salt. Prevents malicious actors from trying to cause collisions against "\0\0\0\0".
          randomFill(sketchSalt)

          #Verify the packets don't collide with our salt.
          while blockTemplate.packets.collides(sketchSalt):
            #This shouldn't be needed as sketchSaltNum is a uint32.
            {.push checks: off.}
            var sketchSaltNum: uint32 = cast[uint32](sketchSalt.fromBinary())
            inc(sketchSaltNum)
            {.pop.}
            sketchSalt = sketchSaltNum.toBinary(INT_LEN)

          #Set the salt now that it's been proven valid.
          blockTemplate.sketchSalt = sketchSalt

          #Create the body for the template.
          try:
            blockTemplate.body = newBlockBodyObj(
              blockTemplate.contents.packets,
              blockTemplate.packets,
              pending.elements,
              pending.aggregate,
              {}
            ).serialize(blockTemplate.sketchSalt, blockTemplate.packets.len)
          except ValueError as e:
            panic("BlockBody's sketch has a collision despite mining a salt which doesn't: " & e.msg)

          #Save the template.
          templates[time] = blockTemplate

        else:
          try:
            blockTemplate = templates[time]
          except KeyError as e:
            panic("Couldn't get the Block Template for this second despite confirming its existence: " & e.msg)

        #Create the Header.
        var
          header: JSONNode = newJNull()
          difficulty: uint64 = functions.merit.getDifficulty()
          headerTime: uint32

        #Ensure the time is higher than the previous Block's.
        try:
          headerTime = max(time, functions.merit.getBlockByHash(tail).header.time + 1)
        except IndexError as e:
          panic("Couldn't get the last Block despite grabbing it by the chain's tail: " & e.msg)

        try:
          var nick: uint16
          try:
            nick = functions.merit.getNickname(miner)
          except IndexError:
            header = % newBlockHeader(
              0,
              tail,
              blockTemplate.contents.contents,
              uint32(blockTemplate.packets.len),
              blockTemplate.sketchSalt,
              newSketchCheck(blockTemplate.sketchSalt, blockTemplate.packets),
              miner,
              headerTime,
              0,
              newBLSSignature()
            ).serializeTemplate().toHex()
            difficulty = difficulty * 11 div 10

          if header.kind == JNull:
            header = % newBlockHeader(
              0,
              tail,
              blockTemplate.contents.contents,
              uint32(blockTemplate.packets.len),
              blockTemplate.sketchSalt,
              newSketchCheck(blockTemplate.sketchSalt, blockTemplate.packets),
              nick,
              headerTime,
              0,
              newBLSSignature()
            ).serializeTemplate().toHex()
        except IndexError as e:
          panic("Couldn't get the Block with a nonce one lower than the height: " & e.msg)
        except BLSError:
          panic("Couldn't create a temporary signature for a BlockHeader template.")

        #Create the result.
        result = %* {
          "id": time,
          "key":  functions.merit.getRandomXCacheKey().toHex(),
          "header": header,
          "difficulty": difficulty
        }

      proc publishBlock(
        id: uint32,
        header: hex
      ) {.forceCheck: [
        JSONRPCError
      ], async.} =
        var
          blockTemplate: BlockTemplate
          sketchyBlock: SketchyBlock
        try:
          blockTemplate = templates[id]
        except KeyError:
          raise newJSONRPCError(IndexError, "Invalid ID")
        try:
          sketchyBlock = functions.merit.getRandomX().parseBlock(header & blockTemplate.body)
        except ValueError:
          raise newJSONRPCError(ValueError, "Invalid Block")

        #Test the Block Header.
        try:
          functions.merit.testBlockHeader(sketchyBlock.data.header)
        except ValueError:
          raise newJSONRPCError(ValueError, "Invalid Block")

        try:
          await functions.merit.addBlock(
            sketchyBlock,
            blockTemplate.packets,
            false
          )
        except KeyError:
          raise newJSONRPCError(KeyError, "Invalid ID")
        except ValueError:
          raise newJSONRPCError(ValueError, "Invalid Block")
        except DataMissing:
          panic("Missing Block-referenced data despite creating this Block's body")
        except Exception as e:
          panic("addBlock threw a raw Exception, despite catching all Exception types it naturally raises: " & e.msg)
  except Exception as e:
    panic("Couldn't create the Merit Module: " & e.msg)
