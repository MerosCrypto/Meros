#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Index object.
import IndexObj
export IndexObj

#Finals lib.
import finals

finalsd:
    #Blocks contain Verifications by reference.
    #This by defining the verifier and the verifier's chain tip (an Index).
    #We successfully detect if the Block is valid and we have the correct Verifications via the aggregate signature.
    #That said, if the aggregate is wrong, we need to check where the problem is.
    #By including merkles, we can find out what specific VERIFIER is under scrutiny.
    type VerifierIndex* = object of Index
        merkle* {.final.}: Hash[384]

#Constructors.
func newVerifierIndex*(
    key: string,
    nonce: Natural,
    merkle: Hash[384]
): VerifierIndex {.forceCheck: [].} =
    result = VerifierIndex(
        merkle: merkle
    )
    try:
        result.key = key
        result.nonce = nonce
    except FinalAttributeError:
        doAssert(false, "Couldn't set the field of a brand new Index due to a FinalAttributeError.")
    result.ffinalizeMerkle()
