#Serialize Receive Test.

#Util lib.
import ../../../../src/lib/Util

#HDWallet lib.
import ../../../../src/Wallet/HDWallet

#LatticeIndex object.
import ../../../../src/Database/common/objects/LatticeIndexObj

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Receive lib.
import ../../../../src/Database/Lattice/Receive

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeReceive
import ../../../../src/Network/Serialize/Lattice/ParseReceive

#Compare Lattice lib.
import ../../../DatabaseTests/LatticeTests/CompareLattice

#Random standard lib.
import random

#Seed random.
randomize(getTime())

var
    #Receive Entry.
    recv: Receive
    #Reloaded Receive Entry.
    reloaded: Receive

#Test 256 serializations.
for _ in 0 .. 255:
    #Create the Receive.
    recv = newReceive(
        newLatticeIndex(
            newHDWallet().next().address,
            rand(high(int32))
        ),
        rand(high(int32))
    )

    #Sign it.
    newHDWallet().next().sign(recv)

    #Serialize it and parse it back.
    reloaded = recv.serialize().parseReceive()

    #Test the serialized versions.
    assert(recv.serialize() == reloaded.serialize())

    #Compare the Entries.
    compare(recv, reloaded)

echo "Finished the Network/Serialize/Lattice/Receive Test."
