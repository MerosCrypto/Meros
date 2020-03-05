#DB Serialize Block Test.

#Test lib.
import unittest

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

    highFuzzTest "Serialize and parse.":
        #Randomize the last hash.
        for b in 0 ..< 32:
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
        reloaded = newBlock.serialize().parseBlock(newBlock.header.hash)

        #Compare the Blocks.
        compare(newBlock, reloaded)

        #Test the serialized versions.
        check(newBlock.serialize() == reloaded.serialize())

        #Flip the newMiner bool.
        newMiner = not newMiner
