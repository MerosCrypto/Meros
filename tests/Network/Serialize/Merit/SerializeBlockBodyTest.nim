import random

import ../../../../src/lib/[Util, Hash, Sketcher]
import ../../../../src/Wallet/MinerWallet

import ../../../../src/Database/Merit/objects/BlockBodyObj

import ../../../../src/Network/objects/SketchyBlockObj
import ../../../../src/Network/Serialize/Merit/[
  SerializeBlockBody,
  ParseBlockBody
]

import ../../../Fuzzed
import ../../../Database/Consensus/Elements/TestElements
import ../../../Database/Merit/CompareMerit

suite "SerializeBlockBody":
  setup:
    var
      sketchSalt: string
      packetsContents: Hash[256] = newRandomHash()
      packets: seq[VerificationPacket] = @[]
      elements: seq[BlockElement] = @[]
      body: BlockBody
      reloaded: SketchyBlockBody
      sketchResult: SketchResult

  highFuzzTest "Serialize and parse.":
    #Randomize the packets.
    for _ in 0 ..< rand(300):
      packets.add(newRandomVerificationPacket())

    #Randomize the elements.
    for _ in 0 ..< rand(300):
      elements.add(newRandomBlockElement())

    #Create the BlockBody with a randomized aggregate signature.
    while true:
      sketchSalt = char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255))

      body = newBlockBodyObj(
        packetsContents,
        packets,
        elements,
        newMinerWallet().sign($rand(4096)),
        {}
      )

      #Verify the sketch doesn't have a collision.
      if newSketcher(packets).collides(sketchSalt):
        continue
      break

    #Serialize it and parse it back.
    reloaded = body.serialize(sketchSalt).parseBlockBody()

    #Create the Sketch and extract its elements.
    sketchResult = newSketcher(packets).merge(
      reloaded.sketch,
      reloaded.capacity,
      0,
      sketchSalt
    )
    check sketchResult.missing.len == 0
    reloaded.data.packets = sketchResult.packets

    #Test the serialized versions.
    check body.serialize(sketchSalt) == reloaded.data.serialize(sketchSalt)

    #Compare the BlockBodies.
    compare(body, reloaded.data)
