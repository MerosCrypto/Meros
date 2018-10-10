#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals

finalsd:
    type
        #Verification object.
        Verification* = ref object of RootObj
            #Sender.
            sender* {.final.}: string
            #Node Hash.
            hash* {.final.}: Hash[512]

        #Verification object for Blocks.
        #It includes the BLS signature for aggregation in the block.
        BlockVerification* = ref object of Verification
            #BLS signature.
            blsSignature* {.final.}: string

        #Verification object for the mempool.
        #It includes the Ed25519 sig which is faster than the BLS sig.
        MemoryVerification* = ref object of BlockVerification
            #Ed25519 signature.
            edSignature* {.final.}: string

        #A group of sender/hash pairs with the final aggregate signature.
        Verifications* = ref object of RootObj
            #Verifications.
            verifications*: seq[Verification]
            #Aggregate signature.
            bls* {.final.}: string

#New Verification object.
func newVerificationObj*(
    hash: Hash[512]
): Verification {.raises: [].} =
    Verification(
        hash: hash
    )

#New BlockVerification object.
func newBlockVerificationObj*(
    hash: Hash[512]
): BlockVerification {.raises: [].} =
    BlockVerification(
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
