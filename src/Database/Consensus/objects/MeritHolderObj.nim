#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Merkle lib.
import ../../common/Merkle

#Verification object.
import VerificationObj

#Serialize lib.
import ../../../Network/Serialize/Consensus/SerializeVerification

#Finals lib.
import finals

#MeritHolder object.
finalsd:
    type MeritHolder* = ref object
        #DB Function Box.
        db: DatabaseFunctionBox

        #Chain owner.
        key* {.final.}: BLSPublicKey
        keyStr* {.final.}: string

        #MeritHolder height.
        height*: Natural
        #Amount of Elements which have been archived.
        archived*: int
        #seq of the Elements.
        elements*: seq[Verification]
        #Merkle of the Elements.
        merkle*: Merkle

#Constructor.
proc newMeritHolderObj*(
    db: DatabaseFunctionBox,
    key: BLSPublicKey
): MeritHolder {.forceCheck: [].} =
    result = MeritHolder(
        db: db,

        key: key,
        keyStr: key.toString(),

        archived: -1,
        elements: @[],
        merkle: newMerkle()
    )
    result.ffinalizeKey()

    #Load our data from the DB.
    try:
        result.archived = parseInt(result.db.get("consensus_" & result.keyStr))
    except ValueError as e:
        doAssert(false, "Couldn't parse the MeritHolder's archived which was successfully retrieved from the Database: " & e.msg)
    #If we're not in the DB, add ourselves.
    except DBReadError:
        try:
            result.db.put("consensus_" & result.keyStr, $result.archived)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a new MeritHolder to the Database: " & e.msg)

    #Populate with the info from the DB.
    result.height = result.archived + 1

# [] operator.
proc `[]`*(
    holder: MeritHolder,
    nonce: Natural
): Verification {.forceCheck: [
    IndexError
].} =
    #Check that the nonce isn't out of bounds.
    if nonce >= holder.height:
        raise newException(IndexError, "That MeritHolder doesn't have a Verification for that nonce.")

    #If it's in the database...
    if nonce <= holder.archived:
        #Grab it and return it.
        try:
            result = newVerificationObj(
                holder.db.get("consensus_" & holder.key.toString() & "_" & nonce.toBinary()).toHash(384)
            )
        except ValueError as e:
            doAssert(false, "Couldn't parse a Verification we were asked for from the Database: " & e.msg)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Verification we were asked for from the Database: " & e.msg)

        try:
            result.holder = holder.key
            result.nonce = nonce
        except FinalAttributeError as e:
            doAssert(false, "Set a final attribute twice when loading a Verification: " & e.msg)
        return

    #Else, return it from memory.
    result = holder.elements[nonce - (holder.archived + 1)]

#Add a Verification to a MeritHolder.
proc add*(
    holder: var MeritHolder,
    verif: Verification
) {.forceCheck: [
    GapError,
    DataExists,
    MeritRemoval
].} =
    #Verify we're not missing Elements.
    if verif.nonce > holder.height:
        raise newException(GapError, "Missing Elements before this Verification.")
    #Verify the Verification's Nonce.
    elif verif.nonce < holder.height:
        #Verify they didn't submit two Elements for the same nonce.
        try:
            if verif.hash != holder[verif.nonce].hash:
                raise newException(MeritRemoval, "MeritHolder submitted two Elements with the same nonce.")
        except IndexError as e:
            doAssert(false, "Couldn't grab a Verification we're supposed to have: " & e.msg)

        #Already added.
        raise newException(DataExists, "Verification has already been added.")

    #Verify this MeritHolder isn't verifying conflicting Transactions.

    #Increase the height.
    holder.height = holder.height + 1
    #Add the Verification to the seq.
    holder.elements.add(verif)
    #Add the Verification to the Merkle.
    holder.merkle.add(verif.hash)

    #Add the Verification to the Database.
    try:
        holder.db.put("consensus_" & holder.key.toString() & "_" & verif.nonce.toBinary(), verif.hash.toString())
    except DBWriteError as e:
        doAssert(false, "Couldn't save a Verification to the Database: " & e.msg)

#Add a SignedVerification to a MeritHolder.
proc add*(
    holder: var MeritHolder,
    verif: SignedVerification
) {.forceCheck: [
    ValueError,
    GapError,
    BLSError,
    DataExists,
    MeritRemoval
].} =
    #Verify the signature.
    try:
        verif.signature.setAggregationInfo(
            newBLSAggregationInfo(verif.holder, cast[Verification](verif).serialize(true))
        )
        if not verif.signature.verify():
            raise newException(ValueError, "Failed to verify the Verification's signature.")
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Add the Verification.
    try:
        holder.add(cast[Verification](verif))
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MeritRemoval as e:
        fcRaise e

#Slice operators.
proc `[]`*(
    holder: MeritHolder,
    slice: Slice[int]
): seq[Verification] {.forceCheck: [
    IndexError
].} =
    #Extract the slice values.
    var
        a: int = slice.a
        b: int = slice.b

    #Support the initial MeritHolder.archived value (-1).
    if a == -1:
        a = 0

    #Make sure it's a valid slice.
    #We would use Natural for this, except `a` can be -1.
    if 0 > a:
        raise newException(IndexError, "Can't get Verification Slice from MeritHolder; a was negative.")
    if a > b:
        raise newException(IndexError, "Can't get Verification Slice from MeritHolder; b was less than a.")

    #Create a seq.
    result = newSeq[Verification](b - a + 1)

    #Grab every Verification.
    try:
        for i in a .. b:
            result[i - a] = holder[i]
    except IndexError as e:
        fcRaise e

proc `{}`*(
    holder: MeritHolder,
    slice: Slice[int]
): seq[SignedVerification] {.forceCheck: [
    IndexError
].} =
    #Extract the slice values.
    var
        a: int = slice.a
        b: int = slice.b

    #Support the initial MeritHolder.archived value (-1).
    if a == -1:
        a = 0

    #Make sure it's a valid slice.
    if 0 > a:
        raise newException(IndexError, "Can't get SignedVerification Slice from MeritHolder; a was negative.")
    if a > b:
        raise newException(IndexError, "Can't get SignedVerification Slice from MeritHolder; b was less than a.")

    #Grab the Elements and cast them.
    try:
        result = cast[seq[SignedVerification]](holder[a .. b])
    except IndexError as e:
        fcRaise e
