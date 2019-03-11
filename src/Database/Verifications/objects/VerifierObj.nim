#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merkle lib.
import ../../../lib/Merkle

#BLS lib.
import ../../../lib/BLS

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Verification object.
import VerificationObj

#Serialize libs.
import ../../../Network/Serialize/Verifications/SerializeVerification
import ../../../Network/Serialize/Verifications/ParseVerification

#String utils standard lib.
import strutils

#Finals lib.
import finals

#Verifier object.
finalsd:
    type Verifier* = ref object of RootObj
        #DB Function Box.
        db: DatabaseFunctionBox

        #Chain owner.
        key* {.final.}: string
        #Verifier height.
        height*: uint
        #Amount of Verifications which have been archived.
        archived*: int
        #seq of the Verifications.
        verifications*: seq[Verification]
        #Merkle of the Verifications.
        merkle*: Merkle

#Constructor.
proc newVerifierObj*(
    db: DatabaseFunctionBox,
    key: string
): Verifier {.raises: [LMDBError].} =
    result = Verifier(
        db: db,

        key: key,
        height: 0,
        archived: -1,
        verifications: @[],
        merkle: newMerkle()
    )
    result.ffinalizeKey()

    #Check if we're in the DB.
    try:
        result.archived = parseInt(result.db.get("verifications_" & result.key.pad(48)))
    #If we're not, add ourselves and return.
    except:
        result.db.put("verifications_" & result.key.pad(48), $result.archived)
        return

    #Populate with the info from the DB.
    result.height = uint(result.archived + 1)

#Add a Verification to a Verifier.
proc add*(verifier: Verifier, verif: Verification) {.raises: [MerosIndexError, LMDBError].} =
    #Verify the Verification's Verifier.
    if verif.verifier.toString() != verifier.key:
        raise newException(MerosIndexError, "Verification's Verifier doesn't match the Verifier we're adding it to.")

    #Verify the Verification's Nonce.
    if verif.nonce != verifier.height:
        if verif.hash != verifier.verifications[int(verif.nonce)].hash:
            #MERIT REMOVAL.
            discard
        #Already added.
        raise newException(MerosIndexError, "Verification has already been added.")

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
    #Add the Verification to the Merkle.
    verifier.merkle.add(verif.hash.toString())

    #Add the Verification to the Database.
    verifier.db.put("verifications_" & verifier.key & "_" & verif.nonce.toBinary(), verif.serialize())

#Add a MemoryVerification to a Verifier.
proc add*(verifier: Verifier, verif: MemoryVerification) {.raises: [MerosIndexError, BLSError, LMDBError].} =
    #Verify the signature.
    verif.signature.setAggregationInfo(
        newBLSAggregationInfo(verif.verifier, verif.hash.toString())
    )
    if not verif.signature.verify():
        raise newException(BLSError, "Failed to verify the Verification's signature.")

    #Add the Verification.
    verifier.add(cast[Verification](verif))

# [] operators.
proc `[]`*(verifier: Verifier, index: int): Verification {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    #Check that the nonce isn't out of bounds.
    if index >= int(verifier.height):
        raise newException(ValueError, "That Verifier doesn't have a Verification for that nonce.")

    #If it's in the database...
    if int(index) <= verifier.archived:
        #Grab it and return it.
        return verifier.db.get("verifications_" & verifier.key & "_" & index.toBinary()).parseVerification()

    #Else, return it from memory.
    result = verifier.verifications[int(index) - (verifier.archived + 1)]
proc `[]`*(verifier: Verifier, index: uint): Verification {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    verifier[int(index)]

proc `[]`*(verifier: Verifier, aArg: int, b: int): seq[Verification] {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    #Support the initial verifier.archived value (-1).
    var a: int = aArg
    if a == -1:
        a = 0

    #Create a seq.
    result = newSeq[Verification](b - a + 1)

    #Grab every Verification.
    for i in a .. b:
        result[int(i - a)] = verifier[i]
proc `[]`*(verifier: Verifier, a: uint, b: uint): seq[Verification] {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    verifier[int(a), int(b)]

proc `{}`*(verifier: Verifier, aArg: int, b: int): seq[MemoryVerification] {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    #Support the initial verifier.archived value (-1).
    var a: int = aArg
    if a == -1:
        a = 0

    #Make sure it's a valid slice.
    if a > b:
        raise newException(ValueError, "That slice is invalid.")

    #Grab the Verifications and cast them.
    var verifs: seq[Verification] = verifier[a, b]
    result = newSeq[MemoryVerification](verifs.len)
    for v in 0 ..< verifs.len:
        result[v] = cast[MemoryVerification](verifs[v])
