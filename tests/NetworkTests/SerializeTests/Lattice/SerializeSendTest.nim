#Serialize Send Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#HDWallet lib.
import ../../../../src/Wallet/HDWallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Send lib.
import ../../../../src/Database/Lattice/Send

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeSend
import ../../../../src/Network/Serialize/Lattice/ParseSend

#Compare Lattice lib.
import ../../../DatabaseTests/LatticeTests/CompareLattice

#Random standard lib.
import random

#Seed random.
randomize(getTime())

var
    #Send Entry.
    send: Send
    #Reloaded Send Entry.
    reloaded: Send

#Test 256 serializations.
for _ in 0 .. 255:
    #Create the Send.
    send = newSend(
        newHDWallet().next().address,
        #This would be an uint64 in an ideal world, but Nim is quirky about int64/uint64 and Ordinal.
        uint64(rand(high(int32))),
        rand(high(int32))
    )

    #Sign it.
    newHDWallet().next().sign(send)
    #Mine the Send.
    send.mine("333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333".toHash(384))

    #Serialize it and parse it back.
    reloaded = send.serialize().parseSend()

    #Test the serialized versions.
    assert(send.serialize() == reloaded.serialize())

    #Compare the Entries.
    compare(send, reloaded)

echo "Finished the Network/Serialize/Lattice/Send Test."
