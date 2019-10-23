#Serialize BlockBody Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Sketcher lib.
import ../../../../src/lib/Sketcher

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../DatabaseTests/ConsensusTests/ElementsTests/TestElements

#BlockBody object.
import ../../../../src/Database/Merit/objects/BlockBodyObj

#SketchyBlockBody object.
import ../../../../src/Network/objects/SketchyBlockObj

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeBlockBody
import ../../../../src/Network/Serialize/Merit/ParseBlockBody

#Compare Merit lib.
import ../../../DatabaseTests/MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
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

    #Test 128 serializations.
    for s in 0 .. 127:
        #Randomize the packets.
        for _ in 0 ..< rand(300):
            packets.add(newRandomVerificationPacket())

        #Randomize the elements.
        for _ in 0 ..< rand(300):
            elements.add(newRandomBlockElement())

        #Create the BlockBody with a randomized aggregate signature.
        while true:
            body = newBlockBodyObj(
                rand(100000),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                packets,
                elements,
                newMinerWallet().sign($rand(4096))
            )

            #Verify the sketch doesn't have a collision.
            if newSketcher(packets).collides(body.sketchSalt):
                continue
            break

        #Serialize it and parse it back.
        reloaded = body.serialize().parseBlockBody()

        #Create the Sketch and extract its elements.
        sketchResult = newSketcher(packets).merge(
            reloaded.packets,
            reloaded.capacity,
            0,
            reloaded.data.sketchSalt
        )
        doAssert(sketchResult.missing.len == 0)
        reloaded.data.packets = sketchResult.packets

        #Test the serialized versions.
        assert(body.serialize() == reloaded.data.serialize())

        #Compare the BlockBodies.
        compare(body, reloaded.data)

        #Clear the packets, and elements.
        packets = @[]
        elements = @[]

    echo "Finished the Network/Serialize/Merit/BlockBody Test."
