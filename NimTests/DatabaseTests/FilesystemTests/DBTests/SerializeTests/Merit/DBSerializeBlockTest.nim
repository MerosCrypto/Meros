#DB Serialize Block Test.

#Util lib.
import ../../../../../../src/lib/Util

#Hash lib.
import ../../../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../../../src/Wallet/MinerWallet

#BlockHeader and Block libs.
import ../../../../../../src/Database/Merit/BlockHeader
import ../../../../../../src/Database/Merit/Block

#Serialize/parse lib.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Merit/DBSerializeBlock
import ../../../../../../src/Database/Filesystem/DB/Serialize/Merit/DBParseBlock

#Elements Testing lib.
import ../../../../ConsensusTests/ElementsTests/TestElements

#Test and Compare Merit lib.
import ../../../../MeritTests/TestMerit
import ../../../../MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed random.
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
        reloaded: Block

    #Test 255 serializations.
    for s in 0 .. 127:
        #Randomize the last hash.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))

        #Randomize the transactions.
        for _ in 0 ..< rand(5):
            for b in 0 ..< 48:
                hash.data[b] = uint8(rand(255))
            transactions.add(hash)

        #Randomize the packets.
        for t in 0 ..< transactions.len:
            packets.add(newRandomVerificationPacket(
                hash = transactions[t]
            ))

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

        #Compare the Blocks.
        compare(newBlock, reloaded)

        #Test the serialized versions.
        assert(newBlock.serialize() == reloaded.serialize())

        #Clear the transactions, packets, and elements.
        transactions = @[]
        packets = @[]
        elements = @[]

    echo "Finished the Database/Filesystem/DB/Serialize/Merit/Block Test."
