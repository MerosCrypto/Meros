#Serialize MeritRemoval Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Element libs.
import ../../../../src/Database/Consensus/Verification

#MeritRemoval lib.
import ../../../../src/Database/Consensus/MeritRemoval

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeMeritRemoval
import ../../../../src/Network/Serialize/Consensus/ParseMeritRemoval

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #MinerWallet.
        miner: MinerWallet
        #Hash.
        hash: Hash[384]
        #Malicious Elements.
        e1: Element
        e2: Element
        #Signature.
        signatures: seq[BLSSignature]
        #SignedMeritRemoval Element.
        mr: SignedMeritRemoval
        #Reloaded MeritRemoval Element.
        reloadedMR: MeritRemoval
        #Reloaded SignedMeritRemoval Element.
        reloadedSMR: SignedMeritRemoval

    #Test 256 serializations.
    for _ in 0 .. 255:
        miner = newMinerWallet()

        for i in 0 ..< 48:
            hash.data[i] = uint8(rand(255))
        e1 = newSignedVerificationObj(hash)

        for i in 0 ..< 48:
            hash.data[i] = uint8(rand(255))
        e2 = newSignedVerificationObj(hash)

        miner.sign(cast[SignedVerification](e1), rand(high(int32)))
        signatures.add(cast[SignedVerification](e1).signature)
        miner.sign(cast[SignedVerification](e2), rand(high(int32)))
        signatures.add(cast[SignedVerification](e2).signature)

        #Create the SignedMeritRemoval.
        mr = newSignedMeritRemoval(
            rand(high(int32)),
            e1,
            e2,
            signatures.aggregate()
        )

        #Serialize it and parse it back.
        reloadedMR = mr.serialize().parseMeritRemoval()
        reloadedSMR = mr.signedSerialize().parseSignedMeritRemoval()

        #Compare the Elements.
        compare(mr, reloadedSMR)
        assert(mr.signature == reloadedSMR.signature)
        compare(mr, reloadedMR)

        #Test the serialized versions.
        assert(mr.serialize() == reloadedMR.serialize())
        assert(mr.signedSerialize() == reloadedSMR.signedSerialize())

    echo "Finished the Network/Serialize/Consensus/MeritRemoval Test."
