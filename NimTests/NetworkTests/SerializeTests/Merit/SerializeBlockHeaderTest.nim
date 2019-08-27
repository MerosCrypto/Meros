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
        #Miners Hash.
        miners: Blake384Hash
        #Block Header.
        header: BlockHeader
        #Reloaded Block Header.
        reloaded: BlockHeader

    #Test 255 serializations.
    for _ in 0 .. 255:
        #Randomize the hashes.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))
            miners.data[b] = uint8(rand(255))

        #Create the BlockHeaader.
        header = newBlockHeader(
            rand(high(int32)),
            last,
            newMinerWallet().sign(rand(high(int32)).toBinary()),
            miners,
            uint32(rand(high(int32))),
            uint32(rand(high(int32)))
        )

        #Serialize it and parse it back.
        reloaded = header.serialize().parseBlockHeader()

        #Test the serialized versions.
        assert(header.serialize() == reloaded.serialize())

        #Compare the BlockHeaders.
        compare(header, reloaded)

    echo "Finished the Network/Serialize/Merit/BlockHeader Test."
