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

#Add a Verification to a Verifier.
proc add*(verifier: Verifier, verif: Verification) {.raises: [].} =
    #Increase the height.
    inc(verifier.height)
    #Add the Verification to the seq.
    verifier.verifications.add(verif)

# [] operators.
func `[]`(verifier: Verifier, index: int): Verification {.raises: [].} =
    verifier.verifications[index]

func `[]`(verifier: Verifier, slice: Slice[int]): seq[Verification] {.raises: [].} =
    verifier.verifications[slice]
