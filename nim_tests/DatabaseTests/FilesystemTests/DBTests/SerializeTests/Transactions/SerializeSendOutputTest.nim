#Serialize SendOutput Test.

#Util lib.
import ../../../../../../src/lib/Util

#Wallet lib.
import ../../../../../../src/Wallet/Wallet

#SendOutput object.
import ../../../../../../src/Database/Transactions/objects/TransactionObj

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/SerializeSendOutput
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/ParseSendOutput

#Compare Transactions lib.
import ../../../../TransactionsTests/CompareTransactions

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    #SendOutputs.
    var
        output: SendOutput
        reloaded: SendOutput

    for _ in 0 .. 255:
        #Create the SendOutput.
        output = newSendOutput(
            newWallet("").publicKey,
            uint64(rand(int32.high))
        )

        #Serialize it and parse it back.
        reloaded = output.serialize().parseSendOutput()

        #Compare the SendOutputs.
        compare(output, reloaded)

        #Test the serialized versions.
        assert(output.serialize() == reloaded.serialize())

    echo "Finished the Database/Filesystem/DB/Serialize/Transactions/SendOutput Test."
