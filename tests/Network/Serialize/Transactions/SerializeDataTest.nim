#Serialize Data Test.

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Wallet libs.
import ../../../../src/Wallet/Wallet

#Data lib.
import ../../../../src/Database/Transactions/Data
import ../../../../src/Database/Transactions/Transaction

#Serialize libs.
import ../../../../src/Network/Serialize/Transactions/SerializeData
import ../../../../src/Network/Serialize/Transactions/ParseData

#Compare Transactions lib.
import ../../../Database/Transactions/CompareTransactions

#Random standard lib.
import random

suite "SerializeData":
    setup:
        var
            #Input.
            input: Hash[256]
            #Data string.
            dataStr: string
            #Data object.
            data: Data
            #Reloaded Data.
            reloaded: Data
            #Wallet.
            wallet: Wallet = newWallet("")

    midFuzzTest "Serialize and parse.":
        #Randomize the input.
        for b in 0 ..< input.data.len:
            input.data[b] = uint8(rand(255))

        #Create the data string.
        dataStr = newString(rand(255) + 1)
        for b in 0 ..< dataStr.len:
            dataStr[b] = char(rand(255))

        #Create the Data.
        data = newData(
            input,
            dataStr
        )

        #Sign the Data.
        wallet.next(last = uint32(rand(200) * 1000)).sign(data)

        #mine the Data.
        data.mine(uint32(5))

        #Serialize it and parse it back.
        reloaded = data.serialize().parseData(uint32(0))

        #Compare the Datas.
        compare(data, reloaded)

        #Test the serialized versions.
        check(data.serialize() == reloaded.serialize())
