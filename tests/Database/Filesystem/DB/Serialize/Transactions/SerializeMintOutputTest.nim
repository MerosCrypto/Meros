#Serialize MintOutput Test.

#Fuzzing lib.
import ../../../../../Fuzzed

#Util lib.
import ../../../../../../src/lib/Util

#MintOutput object.
import ../../../../../../src/Database/Transactions/objects/TransactionObj

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/SerializeMintOutput
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/ParseMintOutput

#Compare Transactions lib.
import ../../../../Transactions/CompareTransactions

#Random standard lib.
import random

suite "SerializeMintOutput":
    lowFuzzTest "Serialize and parse.":
        var
            output: MintOutput
            reloaded: MintOutput

        #Create the MintOutput.
        output = newMintOutput(
            uint16(rand(high(int16))),
            uint64(rand(high(int32)))
        )

        #Serialize it and parse it back.
        reloaded = output.serialize().parseMintOutput()

        #Compare the MintOutputs.
        compare(output, reloaded)

        #Test the serialized versions.
        check(output.serialize() == reloaded.serialize())
