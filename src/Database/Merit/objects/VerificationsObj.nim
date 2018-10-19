#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Miner libs.
import ../Miner/MinerWallet

#Finals lib.
import finals

#String utils standard lib.
import strutils

finalsd:
    type
        #Verification object.
        Verification* = ref object of RootObj
            #BLS Key.
            verifier* {.final.}: BLSPublicKey
            #Entry Hash.
            hash* {.final.}: Hash[512]

        #Verification object for the mempool.
        MemoryVerification* = ref object of Verification
            #BLS signature for aggregation in a block.
            signature* {.final.}: BLSSignature

        #A group of verifier/hash pairs with the final aggregate signature.
        Verifications* = ref object of RootObj
            #Verifications.
            verifications*: seq[MemoryVerification]
            #Aggregate signature.
            aggregate*: BLSSignature

#New Verification object.
func newVerificationObj*(
    hash: Hash[512]
): Verification {.raises: [].} =
    Verification(
        hash: hash
    )

#New MemoryVerification object.
func newMemoryVerificationObj*(
    hash: Hash[512]
): MemoryVerification {.raises: [].} =
    MemoryVerification(
        hash: hash
    )

#New Verifications object.
func newVerificationsObj*(): Verifications {.raises: [].} =
    Verifications(
        verifications: @[]
    )

#Calculate the signature.
proc calculateSig*(verifs: Verifications) {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.verifications.len == 0:
        #Set a 0'd out signature.
        try:
            verifs.aggregate = newBLSSignature(char(0).repeat(96))
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
