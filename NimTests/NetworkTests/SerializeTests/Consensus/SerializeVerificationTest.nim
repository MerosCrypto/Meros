#Serialize Verification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verification lib.
import ../../../../src/Database/Consensus/Elements/Verification

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
        #Hash.
        hash: Hash[384]
        #SignedVerification Element.
        verif: SignedVerification
        #Miner.
        miner: MinerWallet
        #Reloaded Verification Element.
        reloadedV: Verification
        #Reloaded SignedVerification Element.
        reloadedSV: SignedVerification

    #Test 256 serializations.
    for _ in 0 .. 255:
        for i in 0 ..< 48:
            hash.data[i] = uint8(rand(255))

        #Create the SignedVerification.
        verif = newSignedVerificationObj(hash)
        #Sign it.
        miner = newMinerWallet()
        miner.nick = uint32(rand(high(int32)))
        miner.sign(verif)

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
