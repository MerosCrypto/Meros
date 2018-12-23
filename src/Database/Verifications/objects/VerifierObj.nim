#BLS lib.
import ../../../lib/BLS

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

#Constructor.
func newVerifierObj(key: string): Verifier =
    result = Verifier(
        key: key,
        height: 0,
        archived: 0,
        verifications: @[]
    )
    result.ffinalize(key)

#Add a Verification to a Verifier.
proc add*(verifier: Verifier, verif: Verification) {.raises: [].} =
    #Verify the Verification's Verifier.
    if verif.verifier != verifier.key:
        raise newException(IndexError, "Verification's Verifier doesn't match the Verifier we're adding it to.")

    #Verify the Verification's Nonce.
    if verif.nonce != verifier.height:
        if verif.hash != verifier.verifications[verif.nonce].hash:
            #MERIT REMOVAL.
            discard
        #Already added.
        raise new(IndexError, "Verification has already been added.")

    #Verify this isn't a double spend.
    for oldVerif in verifier.verifications:
        if oldVerif.key == verif.key:
            if oldVerif.nonce == verif.nonce:
                if oldVerif.hash != verif.hash:
                    #MERIT REMOVAL.
                    discard

    #Increase the height.
    inc(verifier.height)
    #Add the Verification to the seq.
    verifier.verifications.add(verif)

#Add a MemoryVerification to a Verifier.
proc add*(verifier: Verifier, verif: MemoryVerification) {.raises: [BLSError].} =
    #Verify the signature.
    verif.setAggregateInfo(
        newBLSAggregationInfo(verif.verifier.toString(), verif.hash.toString())
    )
    if not verif.signature.verify():
        raise newException(BLSError, "Failed to verify the Verification's signature.")

    #Add the Verification.
    verifier.add(cast[Verification](verif))

# [] operators.
func `[]`(verifier: Verifier, index: int): Verification {.raises: [].} =
    verifier.verifications[index]

func `[]`(verifier: Verifier, slice: Slice[int]): seq[Verification] {.raises: [].} =
    verifier.verifications[slice]
