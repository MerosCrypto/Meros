#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Merkle lib.
import ../common/Merkle

#Element libs.
import Verification
import MeritRemoval

#MeritHolder object.
import objects/MeritHolderObj
export MeritHolderObj

#Calculate the Merkle.
proc calculateMerkle*(
    holder: MeritHolder,
    nonce: int
): Hash[384] {.forceCheck: [
    IndexError
].} =
    #Calculate how many leaves we're trimming.
    let toTrim: int = holder.height - (nonce + 1)
    if toTrim < 0:
        raise newException(IndexError, "Nonce is out of bounds.")

    #Return the hash of this MeritHolder's trimmed Merkle.
    result = holder.merkle.trim(toTrim).hash

#Calculate the aggregate signature.
proc aggregate*(
    verifs: seq[SignedVerification]
): BLSSignature {.forceCheck: [
    BLSError
].} =
    #If there are no Elements...
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
