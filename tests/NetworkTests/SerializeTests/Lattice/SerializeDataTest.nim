#Serialize Data Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Data lib.
import ../../../../src/Database/Lattice/Data

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeData
import ../../../../src/Network/Serialize/Lattice/ParseData

#Compare Lattice lib.
import ../../../DatabaseTests/LatticeTests/CompareLattice

#Random standard lib.
import random

#Seed random.
randomize(getTime())

var
    #Data string.
    dataStr: string
    #Data Entry.
    data: Data
    #Reloaded Data Entry.
    reloaded: Data

#Test 256 serializations.
for i in 0 .. 255:
    #Create a data string.
    dataStr = ""
    for _ in 0 ..< i:
        dataStr &= char(rand(255))

    #Create the Data.
    data = newData(
        dataStr,
        rand(high(int32))
    )

    #Sign it.
    newWallet().sign(data)
    #Mine the Data.
    data.mine("333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333".toHash(384))

    #Serialize it and parse it back.
    reloaded = data.serialize().parseData()

    #Test the serialized versions.
    assert(data.serialize() == reloaded.serialize())

    #Compare the Entries.
    compare(data, reloaded)

echo "Finished the Network/Serialize/Lattice/Data Test."
