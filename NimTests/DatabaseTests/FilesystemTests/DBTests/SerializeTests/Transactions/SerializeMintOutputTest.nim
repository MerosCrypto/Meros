#Serialize MintOutput Test.

#Util lib.
import ../../../../../../src/lib/Util

#MinerWallet lib.
import ../../../../../../src/Wallet/MinerWallet

#MintOutput object.
import ../../../../../../src/Database/Transactions/objects/TransactionObj

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/SerializeMintOutput
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/ParseMintOutput

#Compare Transactions lib.
import ../../../../TransactionsTests/CompareTransactions

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    #MintOutputs.
    var
        output: MintOutput
        reloaded: MintOutput

    for _ in 0 .. 255:
        #Create the MintOutput.
        output = newMintOutput(
            newMinerWallet().publicKey,
            uint64(rand(int32.high))
        )

        #Serialize it and parse it back.
        reloaded = output.serialize().parseMintOutput()

        #Compare the MintOutputs.
        compare(output, reloaded)

        #Test the serialized versions.
        assert(output.serialize() == reloaded.serialize())

    echo "Finished the Database/Filesystem/DB/Serialize/Transactions/MintOutput Test."
