#Serialize Data Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Wallet libs.
import ../../../../src/Wallet/Wallet

#Data lib.
import ../../../../src/Database/Transactions/Data

#Serialize libs.
import ../../../../src/Network/Serialize/Transactions/SerializeData
import ../../../../src/Network/Serialize/Transactions/ParseData

#Compare Transactions lib.
import ../../../DatabaseTests/TransactionsTests/CompareTransactions

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Input.
        input: Hash[384]
        #Data string.
        dataStr: string
        #Data object.
        data: Data
        #Reloaded Data.
        reloaded: Data
        #Wallet.
        wallet: Wallet = newWallet("")

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the input.
        for b in 0 ..< input.data.len:
            input.data[b] = uint8(rand(255))

        #Create the data string.
        dataStr = newString(rand(254) + 1)
        for b in 0 ..< dataStr.len:
            dataStr[b] = char(rand(255))

        #Create the Data.
        data = newData(
            input,
            dataStr
        )

        #Sign the Data.
        wallet.next(last = uint32(s * 1000)).sign(data)

        #mine the Data.
        data.mine("".pad(96, "cc").toHash(384))

        #Serialize it and parse it back.
        reloaded = data.serialize().parseData()

        #Compare the Datas.
        compare(data, reloaded)

        #Test the serialized versions.
        assert(data.serialize() == reloaded.serialize())

    echo "Finished the Network/Serialize/Transactions/Data Test."
