#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals

#Verification object.
finalsd:
    type Verification* = ref object of RootObj
        #Sender.
        sender* {.final.}: string
        #Node Hash.
        hash* {.final.}: Hash[512]
        #Ed25519 signature.
        edSignature* {.final.}: string
        #BLS signature.
        #blsSignature* {.final.}: string

#New Verification object.
func newVerificationObj*(
    hash: Hash[512]
): Verification {.raises: [].} =
    Verification(
        hash: hash
    )
