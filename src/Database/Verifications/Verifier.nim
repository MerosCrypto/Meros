#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#Finals lib.
import finals

#Calculate the aggregate signature.
proc calculateSig*(verifs: seq[Verification]): BLSSignature {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.len == 0:
        #Set a 0'd out signature.
        try:
            verifs.aggregate = nil
        except:
            raise newException(BLSError, "Couldn't aggregate the signature for the Verifications.")
        return

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
    var agInfos: seq[BLSAggregationInfo] = @[]
    for verif in verifs:
        agInfos.add(
            newBLSAggregationInfo(verif.verifier, verif.hash.toString())
        )

    #Add the aggregated Aggregation Infos to the signature.
    sig.setAggregationInfo(agInfos.aggregate())

    #Verify the signature.
    result = sig.verify()

#Archive a Verification.
proc archive*(verifier: Verifier, nonce: uint, archived: uint) {.raises: [].} =
    verifier[nonce].archive(archived)
