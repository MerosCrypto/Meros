#Serialize Block Test.

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Sketcher lib.
import ../../../../src/lib/Sketcher

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Block lib.
import ../../../../src/Database/Merit/Block

#SketchyBlockBody object.
import ../../../../src/Network/objects/SketchyBlockObj

#Serialize/parse lib.
import ../../../../src/Network/Serialize/Merit/SerializeBlock
import ../../../../src/Network/Serialize/Merit/ParseBlock

#Elements Testing lib.
import ../../../Database/Consensus/Elements/TestElements

#Test and Compare Merit libs.
import ../../../Database/Merit/TestMerit
import ../../../Database/Merit/CompareMerit

#Random standard lib.
import random

#Whether or not to create a Block with a new miner.
var newMiner: bool = true

suite "SerializeBlock":
  setup:
    var
      #Last hash.
      last: Hash[256]
      #Packets.
      packets: seq[VerificationPacket] = @[]
      #Elements.
      elements: seq[BlockElement] = @[]
      #Block.
      newBlock: Block
      #Reloaded Block.
      reloaded: SketchyBlock
      #Sketch Result.
      sketchResult: SketchResult

  highFuzzTest "Serialize and parse.":
    #Randomize the last hash.
    for b in 0 ..< 32:
      last.data[b] = uint8(rand(255))

    #Randomize the packets.
    for _ in 0 ..< rand(300):
      packets.add(newRandomVerificationPacket())

    #Randomize the elements.
    for _ in 0 ..< rand(300):
      elements.add(newRandomBlockElement())

    while true:
      if newMiner:
        newBlock = newBlankBlock(
          getRandomX(),
          uint32(rand(4096)),
          last,
          uint16(rand(50000)),
          char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
          newMinerWallet(),
          packets,
          elements,
          newMinerWallet().sign($rand(4096)),
          uint32(rand(high(int32))),
          uint32(rand(high(int32)))
        )
      else:
        newBlock = newBlankBlock(
          getRandomX(),
          uint32(rand(4096)),
          last,
          uint16(rand(50000)),
          char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
          uint16(rand(high(int16))),
          newMinerWallet(),
          packets,
          elements,
          newMinerWallet().sign($rand(4096)),
          uint32(rand(high(int32))),
          uint32(rand(high(int32)))
        )

      #Verify the sketch doesn't have a collision.
      if newSketcher(packets).collides(newBlock.header.sketchSalt):
        continue
      break

    #Serialize it and parse it back.
    reloaded = getRandomX().parseBlock(newBlock.serialize())

    #Create the Sketch and extract its elements.
    sketchResult = newSketcher(packets).merge(
      reloaded.sketch,
      reloaded.capacity,
      0,
      reloaded.data.header.sketchSalt
    )
    check(sketchResult.missing.len == 0)
    reloaded.data.body.packets = sketchResult.packets

    #Test the serialized versions.
    check(newBlock.serialize() == reloaded.data.serialize())

    #Compare the Blocks.
    compare(newBlock, reloaded.data)

    #Clear the packets and elements.
    packets = @[]
    elements = @[]

    #Flip the newMiner bool.
    newMiner = not newMiner
