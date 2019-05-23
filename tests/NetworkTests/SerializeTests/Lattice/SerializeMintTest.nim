#Serialize Mint Test.

#Util lib.
import ../../../../src/lib/Util

#Wallet libs.
import ../../../../src/Wallet/Wallet
import ../../../../src/Wallet/MinerWallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Mint lib.
import ../../../../src/Database/Lattice/Mint

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeMint
import ../../../../src/Network/Serialize/Lattice/ParseMint

#Compare Lattice lib.
import ../../../DatabaseTests/LatticeTests/CompareLattice

#Random standard lib.
import random

#Seed random.
randomize(getTime())

var
    #Mint Entry.
    mint: Mint
    #Reloaded Mint Entry.
    reloaded: Mint

#Test 256 serializations.
for _ in 0 .. 255:
    #Create the Mint.
    mint = newMint(
        newBLSPrivateKeyFromSeed(rand(high(int32)).toBinary()).getPublicKey(),
        #This would be an uint64 in an ideal world, but Nim is quirky about int64/uint64 and Ordinal.
        uint64(rand(high(int32))),
        rand(high(int32))
    )

    #Serialize it and parse it back.
    reloaded = mint.serialize().parseMint()

    #Test the serialized versions.
    assert(mint.serialize() == reloaded.serialize())

    #Compare the Entries.
    compare(mint, reloaded)

echo "Finished the Network/Serialize/Lattice/Mint Test."
