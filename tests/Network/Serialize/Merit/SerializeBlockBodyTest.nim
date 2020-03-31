#Serialize BlockBody Test.

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

#Elements Testing lib.
import ../../../Database/Consensus/Elements/TestElements

#BlockBody object.
import ../../../../src/Database/Merit/objects/BlockBodyObj

#SketchyBlockBody object.
import ../../../../src/Network/objects/SketchyBlockObj

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeBlockBody
import ../../../../src/Network/Serialize/Merit/ParseBlockBody

#Compare Merit lib.
import ../../../Database/Merit/CompareMerit

#Random standard lib.
import random

suite "SerializeBlockBody":
    setup:
        var
            #Sketch salt.
            sketchSalt: string
            #Packets contents.
            packetsContents: Hash[256]
            #Packets.
            packets: seq[VerificationPacket] = @[]
            #Elements.
            elements: seq[BlockElement] = @[]
            #Block Body.
            body: BlockBody
            #Reloaded Block Body.
            reloaded: SketchyBlockBody
            #Sketch Result.
            sketchResult: SketchResult

    highFuzzTest "Serialize and parse.":
        #Randomize the packets' contents.
        for b in 0 ..< 32:
            packetsContents.data[b] = uint8(rand(255))

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
                newMinerWallet().sign($rand(4096))
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
        check(sketchResult.missing.len == 0)
        reloaded.data.packets = sketchResult.packets

        #Test the serialized versions.
        check(body.serialize(sketchSalt) == reloaded.data.serialize(sketchSalt))

        #Compare the BlockBodies.
        compare(body, reloaded.data)
