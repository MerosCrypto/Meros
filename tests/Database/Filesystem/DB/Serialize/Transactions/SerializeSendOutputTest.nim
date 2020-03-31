#Serialize SendOutput Test.

#Fuzzing lib.
import ../../../../../Fuzzed

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
import ../../../../Transactions/CompareTransactions

#Random standard lib.
import random

suite "SerializeSendOutput":
    lowFuzzTest "Serialize and parse.":
        #SendOutputs.
        var
            output: SendOutput
            reloaded: SendOutput

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
        check(output.serialize() == reloaded.serialize())
