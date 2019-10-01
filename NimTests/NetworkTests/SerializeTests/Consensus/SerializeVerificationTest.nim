#Serialize Verification Test.

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../DatabaseTests/ConsensusTests/ElementsTests/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeVerification
import ../../../../src/Network/Serialize/Consensus/ParseVerification

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #SignedVerification Element.
        verif: SignedVerification
        #Reloaded Verification Element.
        reloadedV: Verification
        #Reloaded SignedVerification Element.
        reloadedSV: SignedVerification

    #Test 256 serializations.
    for _ in 0 .. 255:
        #Create the SignedVerification.
        verif = newRandomVerification()

        #Serialize it and parse it back.
        reloadedV = verif.serialize().parseVerification()
        reloadedSV = verif.signedSerialize().parseSignedVerification()

        #Compare the Elements.
        compare(verif, reloadedSV)
        assert(verif.signature == reloadedSV.signature)
        compare(verif, reloadedV)

        #Test the serialized versions.
        assert(verif.serialize() == reloadedV.serialize())
        assert(verif.signedSerialize() == reloadedSV.signedSerialize())

    echo "Finished the Network/Serialize/Consensus/Verification Test."
