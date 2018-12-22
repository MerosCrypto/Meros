#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#MinerWallet lib.
import MinerWallet

#Verification object.
import objects/VerificationsObj
export VerificationsObj

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Create a new Verification.
func newMemoryVerification*(
    hash: Hash[512]
): MemoryVerification {.raises: [].} =
    newMemoryVerificationObj(hash)

#Sign a Verification.
func sign*(
    miner: MinerWallet,
    verif: MemoryVerification
) {.raises: [FinalAttributeError].} =
    #Set the verifier.
    verif.verifier = miner.publicKey
    #Sign the hash of the Verification.
    verif.signature = miner.sign(verif.hash.toString())

#Calculate the aggregate signature.
proc calculateSig*(verifs: Verifications) {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.verifications.len == 0:
        #Set a 0'd out signature.
        try:
            verifs.aggregate = nil
        except:
            raise newException(BLSError, "Couldn't aggregate the signature for the Verifications.")
        return

    #Declare a seq for the Signatures.
    var sigs: seq[BLSSignature]
    #Put every signature in the seq.
    for verif in verifs.verifications:
        sigs.add(verif.signature)
    #Set the aggregate.
    verifs.aggregate = sigs.aggregate()

#Verify the aggregate signature.
proc verify*(verifs: Verifications): bool {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.verifications.len == 0:
        return true

    #Create the Aggregation Infos.
    var agInfos: seq[BLSAggregationInfo] = @[]
    for verif in verifs.verifications:
        agInfos.add(
            newBLSAggregationInfo(verif.verifier, verif.hash.toString())
        )

    #Add the aggregated Aggregation Infos to the signature.
    verifs.aggregate.setAggregationInfo(agInfos.aggregate())

    #Verify the signature.
    result = verifs.aggregate.verify()
