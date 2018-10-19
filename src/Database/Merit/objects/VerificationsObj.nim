#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Miner libs.
import ../Miner/MinerWallet

#Finals lib.
import finals

#BLS lib.
import BLS

#String utils standard lib.
import strutils

finalsd:
    type
        #Verification object.
        Verification* = ref object of RootObj
            #BLS Key.
            verifier* {.final.}: PublicKey
            #Entry Hash.
            hash* {.final.}: Hash[512]

        #Verification object for the mempool.
        MemoryVerification* = ref object of Verification
            #BLS signature for aggregation in a block.
            signature* {.final.}: Signature

        #A group of verifier/hash pairs with the final aggregate signature.
        Verifications* = ref object of RootObj
            #Verifications.
            verifications*: seq[MemoryVerification]
            #Aggregate signature.
            aggregate*: Signature

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
func calculateSig*(verifs: Verifications) {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.verifications.len == 0:
        #Set a 0'd out signature.
        try:
            verifs.aggregate = newSignatureFromBytes(char(0).repeat(96))
        except:
            raise newException(BLSError, "Couldn't aggregate the signature for the Verifications.")
        return

    #Declare a seq for the Signatures.
    var sigs: seq[Signature]
    #Put every signature in the seq.
    for verif in verifs.verifications:
        sigs.add(verif.signature)
    #Set the aggregate.
    verifs.aggregate = sigs.aggregate()
