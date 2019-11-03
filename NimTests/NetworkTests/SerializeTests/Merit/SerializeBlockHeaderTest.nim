#Serialize BlockHeader Test.

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

#Compare Merit lib.
import ../../../DatabaseTests/MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Last Block's Hash.
        last: ArgonHash
        #Contents Hash.
        contents: Hash[384]
        #Miner.
        miner: MinerWallet
        #Block Header.
        header: BlockHeader
        #Reloaded Block Header.
        reloaded: BlockHeader

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the hashes.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))
            contents.data[b] = uint8(rand(255))

        #Create the BlockHeaader.
        if s < 128:
            #Get a new miner.
            miner = newMinerWallet()

            header = newBlockHeader(
                uint32(rand(high(int32))),
                last,
                contents,
                uint16(rand(50000)),
                char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
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
                uint16(rand(high(int16))),
                uint32(rand(high(int32)))
            )
        miner.hash(header, uint16(rand(high(int16))))

        #Serialize it and parse it back.
        reloaded = header.serialize().parseBlockHeader()

        #Test the serialized versions.
        #assert(header.serialize() == reloaded.serialize())

        #Compare the BlockHeaders.
        compare(header, reloaded)

    echo "Finished the Network/Serialize/Merit/BlockHeader Test."
