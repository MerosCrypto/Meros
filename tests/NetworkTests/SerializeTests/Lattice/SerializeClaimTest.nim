#Serialize Claim Test.

#Util lib.
import ../../../../src/lib/Util

#Wallet libs.
import ../../../../src/Wallet/Wallet
import ../../../../src/Wallet/MinerWallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Claim lib.
import ../../../../src/Database/Lattice/Claim

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeClaim
import ../../../../src/Network/Serialize/Lattice/ParseClaim

#Compare Lattice lib.
import ../../../DatabaseTests/LatticeTests/CompareLattice

#Random standard lib.
import random

#Seed random.
randomize(getTime())

var
    #Claim Entry.
    claim: Claim
    #Reloaded Claim Entry.
    reloaded: Claim

#Test 256 serializations.
for _ in 0 .. 255:
    #Create the Claim.
    claim = newClaim(
        rand(high(int32)),
        rand(high(int32))
    )

    #Sign it.
    claim.sign(newMinerWallet(), newWallet())

    #Serialize it and parse it back.
    reloaded = claim.serialize().parseClaim()

    #Test the serialized versions.
    assert(claim.serialize() == reloaded.serialize())

    #Compare the Entries.
    compare(claim, reloaded)

echo "Finished the Network/Serialize/Lattice/Claim Test."
