#Serialize Unknown Test.

#Util lib.
import ../../../../../../src/lib/Util

#Hash lib.
import ../../../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../../../src/Wallet/MinerWallet

#Verification lib.
import ../../../../../../src/Database/Consensus/Verification

#Serialize/Parse Unknown.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Consensus/SerializeUnknown
import ../../../../../../src/Database/Filesystem/DB/Serialize/Consensus/ParseUnknown

#Compare Consensus lib.
import ../../../../ConsensusTests/CompareConsensus

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Hash.
        hash: Hash[384]
        #Verification of an Unknown hash.
        verif: Verification
        #Reloaded Unknown.
        reloaded: Verification

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the hash.
        for b in 0 ..< 48:
            hash.data[b] = uint8(rand(255))

        #Create the verification.
        verif = newVerificationObj(hash)
        verif.holder = newMinerWallet().publicKey

        #Serialize it and parse it back.
        reloaded = serializeUnknown(verif.hash.toString(), verif.holder).parseUnknown()

        #Test the serialized versions.
        assert(serializeUnknown(verif.hash.toString(), verif.holder) == serializeUnknown(reloaded.hash.toString(), reloaded.holder))

        #Compare the Verification.
        compare(verif, reloaded)

    echo "Finished the Database/Filesystem/DB/Serialize/Consensus/Unknown Test."
