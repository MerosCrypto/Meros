#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Merkle lib.
import ../../lib/Merkle

#BLS lib.
import ../../lib/BLS

#Verifier object.
import objects/VerifierObj
export VerifierObj

#Verification lib.
import Verification

#Finals lib.
import finals

#Calculate the Merkle.
proc calculateMerkle*(verifier: Verifier, nonce: uint): string {.raises: [].} =
    #Create a seq for the hashes.
    var hashes: seq[string] = newSeq[string](nonce)
    #Grab every Verificaion up to, but including, this nonce, for this Verifier.
    for verif in verifier[uint(0) .. nonce]:
        #Add its hash to the seq.
        hashes.add(verif.hash.toString())
    #Create the Merkle Tree and return the hash.
    result = newMerkle(hashes).hash

#Calculate the aggregate signature.
proc calculateSig*(verifs: seq[MemoryVerification]): BLSSignature {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.len == 0:
        return nil

    #Declare a seq for the Signatures.
    var sigs: seq[BLSSignature]
    #Put every signature in the seq.
    for verif in verifs:
        sigs.add(verif.signature)
    #Set the aggregate.
    result = sigs.aggregate()

#Verify the aggregate signature.
proc verify*(verifs: seq[Verification], sig: BLSSignature): bool {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.len == 0:
        return sig == nil


    #Create the Aggregation Infos.
    var agInfos: seq[ptr BLSAggregationInfo] = @[]
    try:
        for verif in verifs:
            agInfos.add(cast[ptr BLSAggregationInfo](alloc0(sizeof(BLSAggregationInfo))))
            agInfos[^1][] = newBLSAggregationInfo(verif.verifier, verif.hash.toString())
    except:
        raise newException(BLSError, "Couldn't allocate space for the AggregationInfo.")

    #Add the aggregated Aggregation Infos to the signature.
    sig.setAggregationInfo(agInfos.aggregate())

    #Verify the signature.
    result = sig.verify()
