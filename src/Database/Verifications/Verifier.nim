#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Merkle lib.
import ../common/Merkle

#Verification lib.
import Verification

#Verifier object.
import objects/VerifierObj
export VerifierObj

#Calculate the Merkle.
proc calculateMerkle*(
    verifier: Verifier,
    nonce: Natural
): Hash[384] {.forceCheck: [
    IndexError
].} =
    #Calculate how many leaves we're trimming.
    let toTrim: int = verifier.height - (nonce + 1)
    if toTrim < 0:
        raise newException(IndexError, "Nonce is out of bounds.")

    #Return the hash of this Verifier's trimmed Merkle.
    result = verifier.merkle.trim(toTrim).hash

#Calculate the aggregate signature.
proc aggregate*(
    verifs: seq[MemoryVerification]
): BLSSignature {.forceCheck: [
    BLSError
].} =
    #If there's no Verifications...
    if verifs.len == 0:
        return nil

    #Declare a seq for the Signatures.
    var sigs: seq[BLSSignature] = newSeq[BLSSignature](verifs.len)
    #Put every signature in the seq.
    for i in 0 ..< verifs.len:
        sigs.add(verifs[i].signature)

    #Return the aggregate.
    try:
        result = sigs.aggregate()
    except BLSError as e:
        fcRaise e
