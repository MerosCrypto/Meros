#Serialize Mint Test.

#Util lib.
import ../../../../../../src/lib/Util

#Hash lib.
import ../../../../../../src/lib/Hash

#Epochs lib.
import ../../../../../../src/Database/Merit/Epochs

#Mint lib.
import ../../../../../../src/Database/Transactions/Mint

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/SerializeMint
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/ParseMint

#Compare Transactions lib.
import ../../../../TransactionsTests/CompareTransactions

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Mint.
        mint: Mint
        #Reloaded Mint.
        reloaded: Mint

        #Hash.
        hash: Hash[384]
        #Outputs.
        outputs: seq[MintOutput]

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the hash.
        for b in 0 ..< hash.data.len:
            hash.data[b] = uint8(rand(255))

        #Randomize the outputs.
        outputs = newSeq[MintOutput](rand(99) + 1)
        for o in 0 ..< outputs.len:
            outputs[o] = newMintOutput(uint16(rand(65535)), uint64(rand(high(int32))))

        #Create the Mint.
        mint = newMint(hash, outputs)

        #Serialize it and parse it back.
        reloaded = hash.parseMint(mint.serialize())

        #Compare the Mints.
        compare(mint, reloaded)

        #Test the serialized versions.
        assert(mint.serialize() == reloaded.serialize())

    echo "Finished the Database/Filesystem/DB/Serialize/Transactions/Mint Test."
