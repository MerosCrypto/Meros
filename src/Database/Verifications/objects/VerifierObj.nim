#Verification object.
import VerificationObj

#Finals lib.
import finals

#Verifier object.
finalsd:
    type Verifier* = ref object of RootObj
        #Chain owner.
        key* {.final.}: string
        #Verifier height.
        height*: uint
        #Amount of Verifications which have been archived.
        archived*: uint
        #seq of the Verifications.
        verifications*: seq[Verification]

# [] operators.
func `[]`(verifier: Verifier, index: int): Verification {.raises: [].} =
    verifier.verifications[index]

func `[]`(verifier: Verifier, slice: Slice[int]): seq[Verification] {.raises: [].} =
    verifier.verifications[slice]
