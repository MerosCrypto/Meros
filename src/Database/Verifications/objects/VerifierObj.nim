#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

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
func newVerifierObj*(key: string): Verifier =
    result = Verifier(
        key: key,
        height: 0,
        archived: 0,
        verifications: @[]
    )
    result.ffinalizeKey()

#Add a Verification to a Verifier.
proc add*(verifier: Verifier, verif: Verification) {.raises: [EmbIndexError].} =
    #Verify the Verification's Verifier.
    if verif.verifier.toString() != verifier.key:
        raise newException(EmbIndexError, "Verification's Verifier doesn't match the Verifier we're adding it to.")

    #Verify the Verification's Nonce.
    if verif.nonce != verifier.height:
        if verif.hash != verifier.verifications[int(verif.nonce)].hash:
            #MERIT REMOVAL.
            discard
        #Already added.
        raise newException(EmbIndexError, "Verification has already been added.")

    #Verify this isn't a double spend.
    for oldVerif in verifier.verifications:
        if oldVerif.verifier == verif.verifier:
            if oldVerif.nonce == verif.nonce:
                if oldVerif.hash != verif.hash:
                    #MERIT REMOVAL.
                    discard

    #Increase the height.
    inc(verifier.height)

    #Add the Verification to the seq.
    verifier.verifications.add(verif)

#Add a MemoryVerification to a Verifier.
proc add*(verifier: Verifier, verif: MemoryVerification) {.raises: [BLSError, EmbIndexError].} =
    #Verify the signature.
    verif.signature.setAggregationInfo(
        newBLSAggregationInfo(verif.verifier, verif.hash.toString())
    )
    if not verif.signature.verify():
        raise newException(BLSError, "Failed to verify the Verification's signature.")

    #Add the Verification.
    verifier.add(cast[Verification](verif))

# [] operators.
func `[]`*(verifier: Verifier, index: uint): Verification {.raises: [].} =
    verifier.verifications[int(index)]

func `[]`*(verifier: Verifier, slice: Slice[uint]): seq[Verification] {.raises: [].} =
    verifier.verifications[int(slice.a) .. int(slice.b)]

func `{}`*(verifier: Verifier, slice: Slice[uint]): seq[MemoryVerification] {.raises: [].} =
    var verifs: seq[Verification] = verifier.verifications[slice]
    result = newSeq[MemoryVerification](verifs.len)
    for v in 0 ..< verifs.len:
        result[v] = cast[MemoryVerification](verifs[v])
