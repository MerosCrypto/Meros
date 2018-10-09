#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals

#Verification object.
finalsd:
    type Verification = ref object of RootObj
        #Sender.
        sender* {.final.}: string
        #Node Hash.
        hash* {.final.}: Hash[512]
        #BLS signature.
        blsSignature* {.final.}: string

    type MemoryVerification* = ref object of Verification
        #Ed25519 signature.
        edSignature* {.final.}: string

#New Verification object.
func newMemoryVerificationObj*(
    hash: Hash[512]
): MemoryVerification {.raises: [].} =
    MemoryVerification(
        hash: hash
    )
