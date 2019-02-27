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
        archived*: uint
        #seq of the Verifications.
        verifications*: seq[Verification]
        #Merkle of the Verifications.
        merkle*: Merkle

#Constructor.
proc newVerifierObj*(key: string, db: DatabaseFunctionBox): Verifier {.raises: [LMDBError].} =
    result = Verifier(
        db: db,

        key: key,
        height: 0,
        archived: 0,
        verifications: @[],
        merkle: newMerkle()
    )
    result.ffinalizeKey()

    #Check if we're in the DB.
    try:
        discard result.db.get("verifications_" & result.key)
    except:
        #If we're not, add ourselves and return.
        result.db.put("verifications_" & result.key, 0.toBinary())
        return

    #Populate with the info from the DB.
    var height: uint = uint(result.db.get("verifications_" & result.key).fromBinary())
    result.height = height
    if height == 0:
        result.archived = height
    else:
        result.archived = height - 1

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
proc `[]`*(verifier: Verifier, index: uint): Verification {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    #Check that the nonce isn't out of bounds.
    if index >= verifier.height:
        raise newException(ValueError, "That Verifier doesn't have a Verification for that nonce.")

    #If it's in the database...
    if index <= verifier.archived:
        #Grab it and return it.
        return verifier.db.get("verifications_" & verifier.key & "_" & index.toBinary()).parseVerification()

    #Else, return it from memory.
    result = verifier.verifications[int(index) - int(verifier.archived + 1)]

proc `[]`*(verifier: Verifier, slice: Slice[uint]): seq[Verification] {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    #Create a seq.
    result = newSeq[Verification](slice.b - slice.a + 1)

    #Grab every Verification.
    for i in slice:
        result[int(i - slice.a)] = verifier[i]

proc `{}`*(verifier: Verifier, sliceArg: Slice[uint]): seq[MemoryVerification] {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    #Calculate the new Slice.
    var slice: Slice[uint]
    slice.a = sliceArg.a - (verifier.archived + 1)
    slice.b = sliceArg.b - (verifier.archived + 1)

    #Make sure it's within bounds.
    if slice.a > slice.b:
        raise newException(ValueError, "That Verifier doesn't have the MemoryVerifications for that slice.")
    if slice.b >= uint(verifier.verifications.len):
        raise newException(ValueError, "That Verifier doesn't have the MemoryVerifications for that slice.")

    #Grab the Verifications and cast them.
    var verifs: seq[Verification] = verifier[slice]
    result = newSeq[MemoryVerification](verifs.len)
    for v in 0 ..< verifs.len:
        result[v] = cast[MemoryVerification](verifs[v])
