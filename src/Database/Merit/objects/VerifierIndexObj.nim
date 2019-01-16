#Index object.
import ../../common/objects/IndexObj
#Export the Index object.
export IndexObj

#Finals lib.
import finals

finalsd:
    #Blocks contain Verifications by reference.
    #This by defining the verifier and the verifier's chain tip (an Index).
    #We successfully detect if the Block is valid and we have the correct Verifications via the aggregate signature.
    #That said, if the aggregate is wrong, we need to check where the problem is.
    #By including merkles, we can find out what specific VERIFIER is under scrutiny.
    type VerifierIndex* = ref object of Index
        merkle* {.final.}: string

#Constructors.
func newVerifierIndex*(
    key: string,
    nonce: uint,
    merkle: string
): VerifierIndex {.raises: [FinalAttributeError].} =
    result = VerifierIndex()
    result.key = key
    result.nonce = nonce
    result.merkle = merkle
    result.ffinalizeMerkle()
