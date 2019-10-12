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
        #Hash.
        hash: Hash[384]
        #Last hash.
        last: ArgonHash
        #Transactions.
        transactions: seq[Hash[384]] = @[]
        #Packets.
        packets: seq[VerificationPacket] = @[]
        #Elements.
        elements: seq[BlockElement] = @[]
        #Block.
        newBlock: Block
        #Reloaded Block.
        reloaded: tuple[
            data: Block,
            capacity: int,
            transactions: string,
            packets: string
        ]
        #Sketch Results.
        txsResult: SketchResult[Hash[384]]
        packetsResult: SketchResult[VerificationPacket]

    #Test 128 serializations.
    for s in 0 .. 127:
        #Randomize the last hash.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))

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

        if s < 64:
            newBlock = newBlankBlock(
                uint32(rand(4096)),
                last,
                newMinerWallet(),
                rand(100000),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                transactions,
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
                uint16(rand(high(int16))),
                newMinerWallet(),
                rand(100000),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                transactions,
                packets,
                elements,
                newMinerWallet().sign($rand(4096)),
                uint32(rand(high(int32))),
                uint32(rand(high(int32)))
            )

        #Serialize it and parse it back.
        reloaded = newBlock.serialize().parseBlock()

        #Create the Sketches and extract the elements in each.
        txsResult = newSketcher(transactions).merge(
            reloaded.transactions,
            reloaded.capacity,
            0,
            reloaded.data.body.sketchSalt
        )
        doAssert(txsResult.missing.len == 0)
        reloaded.data.body.transactions = txsResult.elements

        packetsResult = newSketcher(packets).merge(
            reloaded.packets,
            reloaded.capacity,
            0,
            reloaded.data.body.sketchSalt
        )
        doAssert(packetsResult.missing.len == 0)
        reloaded.data.body.packets = packetsResult.elements

        #Test the serialized versions.
        assert(newBlock.serialize() == reloaded.data.serialize())

        #Compare the Blocks.
        compare(newBlock, reloaded.data)

        #Clear the transactions, packets, and elements.
        transactions = @[]
        packets = @[]
        elements = @[]

    echo "Finished the Network/Serialize/Merit/Block Test."
