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
        #Hash.
        hash: Hash[384]
        #Transactions.
        transactions: seq[Hash[384]] = @[]
        #Packets.
        packets: seq[VerificationPacket] = @[]
        #Elements.
        elements: seq[BlockElement] = @[]
        #Block Body.
        body: BlockBody
        #Reloaded Block Body.
        reloaded: SketchyBlockBody
        #Sketch Results.
        txsResult: SketchResult[Hash[384]]
        packetsResult: SketchResult[VerificationPacket]

    #Test 128 serializations.
    for s in 0 .. 127:
        #Randomize the transactions.
        for _ in 0 ..< rand(300):
            for b in 0 ..< 48:
                hash.data[b] = uint8(rand(255))
            transactions.add(hash)

        #Randomize the packets.
        for _ in 0 ..< transactions.len:
            packets.add(newRandomVerificationPacket())

        #Randomize the elements.
        for _ in 0 ..< rand(300):
            elements.add(newRandomBlockElement())

        #Create the BlockBody with a randomized aggregate signature.
        body = newBlockBodyObj(
            rand(100000),
            char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
            transactions,
            packets,
            elements,
            newMinerWallet().sign($rand(4096))
        )

        #Serialize it and parse it back.
        reloaded = body.serialize().parseBlockBody()

        #Create the Sketches and extract the elements in each.
        txsResult = newSketcher(transactions).merge(
            reloaded.transactions,
            reloaded.capacity,
            0,
            reloaded.data.sketchSalt
        )
        doAssert(txsResult.missing.len == 0)
        reloaded.data.transactions = txsResult.elements

        packetsResult = newSketcher(packets).merge(
            reloaded.packets,
            reloaded.capacity,
            0,
            reloaded.data.sketchSalt
        )
        doAssert(packetsResult.missing.len == 0)
        reloaded.data.packets = packetsResult.elements

        #Test the serialized versions.
        assert(body.serialize() == reloaded.data.serialize())

        #Compare the BlockBodies.
        compare(body, reloaded.data)

        #Clear the transactions, packets, and elements.
        transactions = @[]
        packets = @[]
        elements = @[]

    echo "Finished the Network/Serialize/Merit/BlockBody Test."
