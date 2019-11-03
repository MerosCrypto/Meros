#Serialize Block Test.

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
import ../../../DatabaseTests/ConsensusTests/ElementsTests/TestElements

#Test and Compare Merit libs.
import ../../../DatabaseTests/MeritTests/TestMerit
import ../../../DatabaseTests/MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Last hash.
        last: ArgonHash
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

    #Test 128 serializations.
    for s in 0 .. 127:
        #Randomize the last hash.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))

        #Randomize the packets.
        for _ in 0 ..< rand(300):
            packets.add(newRandomVerificationPacket())

        #Randomize the elements.
        for _ in 0 ..< rand(300):
            elements.add(newRandomBlockElement())

        while true:
            if s < 64:
                newBlock = newBlankBlock(
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
        reloaded = newBlock.serialize().parseBlock()

        #Create the Sketch and extract its elements.
        sketchResult = newSketcher(packets).merge(
            reloaded.sketch,
            reloaded.capacity,
            0,
            reloaded.data.header.sketchSalt
        )
        doAssert(sketchResult.missing.len == 0)
        reloaded.data.body.packets = sketchResult.packets

        #Test the serialized versions.
        assert(newBlock.serialize() == reloaded.data.serialize())

        #Compare the Blocks.
        compare(newBlock, reloaded.data)

        #Clear the packets, and elements.
        packets = @[]
        elements = @[]

    echo "Finished the Network/Serialize/Merit/Block Test."
