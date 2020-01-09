#DB Serialize Block Test.

#Test lib.
import unittest2

#Fuzzing lib.
import ../../../../../Fuzzed

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
import ../../../../Consensus/Elements/TestElements

#Test and Compare Merit lib.
import ../../../../Merit/TestMerit
import ../../../../Merit/CompareMerit

#Random standard lib.
import random

#Whether or not to create a Block with a new miner.
var newMiner: bool = true

suite "DBSerializeBlock":
    setup:
        #Seed random.
        randomize(int64(getTime()))

        var
            #Last hash.
            last: RandomXHash
            #Packets.
            packets: seq[VerificationPacket] = @[]
            #Elements.
            elements: seq[BlockElement] = @[]
            #Block.
            newBlock: Block
            #Reloaded Block.
            reloaded: Block

    highFuzzTest "Block with a VerificationPacket with 256 holders.":
        #Hash.
        var hash: Hash[384]
        for b in 0 ..< 48:
            hash.data[b] = uint8(rand(255))

        packets.add(newVerificationPacketObj(hash))

        #Randomize the participating holders.
        packets[0].holders = newSeq[uint16](256)
        for h in 24 ..< 256:
            packets[0].holders[h] = uint16(65535 - (256 - h))

        packets.add(newVerificationPacketObj(hash))
        packets[1].holders = @[uint16(0)]

        var miner: MinerWallet = newMinerWallet(parseHexStr("0000000000000000000000000000000033B6A75DDA4FA4283F7F073EB8CAAD671C67CF17349D8EF479EC70E6265DB7F5"))
        newBlock = newBlankBlock(
            uint32(2050),
            last,
            uint16(40520),
            "Test",
            miner,
            packets,
            @[],
            miner.sign(""),
            uint32(3500000),
            uint32(2501500)
        )

        #Serialize it and parse it back.
        reloaded = newBlock.serialize().parseBlock()

        #Compare the Blocks.
        compare(newBlock, reloaded)

        #Test the serialized versions.
        check(newBlock.serialize() == reloaded.serialize())

    highFuzzTest "Serialize and parse.":
        #Randomize the last hash.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))

        #Randomize the packets.
        for p in 0 ..< rand(300):
            packets.add(newRandomVerificationPacket())

        #Randomize the elements.
        for _ in 0 ..< rand(300):
            elements.add(newRandomBlockElement())

        if newMiner:
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

        #Serialize it and parse it back.
        reloaded = newBlock.serialize().parseBlock()

        #Compare the Blocks.
        compare(newBlock, reloaded)

        #Test the serialized versions.
        check(newBlock.serialize() == reloaded.serialize())

        #Flip the newMiner bool.
        newMiner = not newMiner
