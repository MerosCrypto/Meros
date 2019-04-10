#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merkle lib.
import ../../common/Merkle

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Verification object.
import VerificationObj

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
        height*: Natural
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
): Verifier {.raises: [].} =
    result = Verifier(
        db: db,

        key: key,
        archived: -1,
        verifications: @[],
        merkle: newMerkle()
    )
    result.ffinalizeKey()

    #Load our data from the DB.
    try:
        try:
            result.archived = parseInt(result.db.get("verifications_" & result.key))
        except ValueError as e:
            doAssert(false, "Couldn't parse the Verifier's archived which was successfully retrieved from the Database: " & e.msg)

        #Recreate the Merkle tree.
        try:
            for i in 0 .. result.archived:
                result.merkle.add(
                    result.db.get("verifications_" & result.key & "_" & i.toBinary()).toHash(384)
                )
        except ValueError as e:
            doAssert(false, "Couldn't load the Verifier's Merkle from the Database: " & e.msg)
    #If we're not in the DB, add ourselves.
    except DBReadError:
        try:
            result.db.put("verifications_" & result.key, $result.archived)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a new Verifier to the Database: " & e.msg)

    #Populate with the info from the DB.
    result.height = result.archived + 1

#Add a Verification to a Verifier.
proc add*(verifier: Verifier, verif: Verification) {.raises: [MerosIndexError, DBError].} =
    #Verify the Verification's Verifier.
    if verif.verifier.toString() != verifier.key:
        raise newException(MerosIndexError, "Verification's Verifier doesn't match the Verifier we're adding it to.")

    #Verify the Verification's Nonce.
    if verif.nonce != verifier.height:
        if verif.hash != verifier.verifications[verif.nonce].hash:
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
    verifier.merkle.add(verif.hash)

    #Add the Verification to the Database.
    verifier.db.put("verifications_" & verifier.key & "_" & verif.nonce.toBinary(), verif.hash.toString())

#Add a MemoryVerification to a Verifier.
proc add*(verifier: Verifier, verif: MemoryVerification) {.raises: [MerosIndexError, BLSError, DBError].} =
    #Verify the signature.
    verif.signature.setAggregationInfo(
        newBLSAggregationInfo(verif.verifier, verif.hash.toString())
    )
    if not verif.signature.verify():
        raise newException(BLSError, "Failed to verify the Verification's signature.")

    #Add the Verification.
    verifier.add(cast[Verification](verif))

# [] operators.
proc `[]`*(verifier: Verifier, index: Natural): Verification {.raises: [ValueError, BLSError, DBError, FinalAttributeError].} =
    #Check that the nonce isn't out of bounds.
    if index >= verifier.height:
        raise newException(ValueError, "That Verifier doesn't have a Verification for that nonce.")

    #If it's in the database...
    if index <= verifier.archived:
        #Grab it and return it.
        result = newVerificationObj(
            verifier.db.get("verifications_" & verifier.key & "_" & index.toBinary()).toHash(384)
        )
        result.verifier = newBLSPublicKey(verifier.key)
        result.nonce = index
        return

    #Else, return it from memory.
    result = verifier.verifications[index - (verifier.archived + 1)]

proc `[]`*(verifier: Verifier, slice: Slice[int]): seq[Verification] {.raises: [ValueError, BLSError, DBError, FinalAttributeError].} =
    #Extract the slice values.
    var
        a: int = slice.a
        b: int = slice.b

    #Support the initial verifier.archived value (-1).
    if a == -1:
        a = 0

    #Make sure it's a valid slice.
    #We would use Natural for this, except a can be -1.
    #These assertions are off when range checks are off.
    assert(0 <= a, "Can't get Verification Slice from Verifier; a was negative.")
    assert(a <= b, "Can't get Verification Slice from Verifier; b was less than a.")

    #Create a seq.
    result = newSeq[Verification](b - a + 1)

    #Grab every Verification.
    for i in a .. b:
        result[i - a] = verifier[i]

proc `{}`*(verifier: Verifier, slice: Slice[int]): seq[MemoryVerification] {.raises: [ValueError, BLSError, DBError, FinalAttributeError].} =
    #Extract the slice values.
    var
        a: int = slice.a
        b: int = slice.b

    #Support the initial verifier.archived value (-1).
    if a == -1:
        a = 0

    #Make sure it's a valid slice.
    assert(0 <= a, "Can't get MemoryVerification Slice from Verifier; a was negative.")
    assert(a <= b, "Can't get MemoryVerification Slice from Verifier; b was less than a.")

    #Grab the Verifications and cast them.
    var verifs: seq[Verification] = verifier[a .. b]
    result = newSeq[MemoryVerification](verifs.len)
    for v in 0 ..< verifs.len:
        result[v] = cast[MemoryVerification](verifs[v])
