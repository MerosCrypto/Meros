#Serialize BlockHeader Test.

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#BlockHeader lib.
import ../../../../src/Database/Merit/BlockHeader

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeBlockHeader
import ../../../../src/Network/Serialize/Merit/ParseBlockHeader

#Test and Compare Merit libs.
import ../../../Database/Merit/TestMerit
import ../../../Database/Merit/CompareMerit

#Random standard lib.
import random

#Whether or not to create a BlockHeader with a new miner.
var newMiner: bool = true

suite "SerializeBlockHeader":
    midFuzzTest "Serialize and parse.":
        var
            #Last Block's Hash.
            last: RandomXHash
            #Contents Hash.
            contents: Hash[256]
            #Sketch Check Merkle.
            sketchCheck: Hash[256]
            #Miner.
            miner: MinerWallet
            #Block Header.
            header: BlockHeader
            #Reloaded Block Header.
            reloaded: BlockHeader

        #Randomize the hashes.
        for b in 0 ..< 32:
            last.data[b] = uint8(rand(255))
            contents.data[b] = uint8(rand(255))
            sketchCheck.data[b] = uint8(rand(255))

        #Create the BlockHeaader.
        if newMiner:
            #Get a new miner.
            miner = newMinerWallet()

            header = newBlockHeader(
                uint32(rand(high(int32))),
                last,
                contents,
                uint16(rand(50000)),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                sketchCheck,
                miner.publicKey,
                uint32(rand(high(int32)))
            )
        else:
            header = newBlockHeader(
                uint32(rand(high(int32))),
                last,
                contents,
                uint16(rand(50000)),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
                sketchCheck,
                uint16(rand(high(int16))),
                uint32(rand(high(int32)))
            )
        getRandomX().hash(miner, header, uint16(rand(high(int16))))

        #Serialize it and parse it back.
        reloaded = getRandomX().parseBlockHeader(header.serialize())

        #Compare the BlockHeaders.
        compare(header, reloaded)

        #Test the serialized versions.
        check(header.serialize() == reloaded.serialize())

        #Serialize it and parse it back with the hashes.
        reloaded = header.serialize().parseBlockHeader(header.interimHash, header.hash)

        #Test it.
        compare(header, reloaded)
        check(header.serialize() == reloaded.serialize())

        #Flip the newMiner bool.
        newMiner = not newMiner
