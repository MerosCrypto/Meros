#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Consensus DB lib.
import ../../Filesystem/DB/ConsensusDB

#Merkle lib.
import ../../common/Merkle

#Element lin.
import ../Element as ElementFile

#Serialize lib.
import ../../../Network/Serialize/Consensus/SerializeElement

#Finals lib.
import finals

#Tables standard lib.
import tables

#MeritHolder object.
finalsd:
    type MeritHolder* = ref object
        #DB Function Box.
        db: DB

        #Chain owner.
        key* {.final.}: BLSPublicKey
        keyStr* {.final.}: string

        #MeritHolder height.
        height*: int
        #Amount of Elements which have been archived.
        archived*: int

        #Signatures of pending Elements.
        signatures*: Table[int, BLSSignature]
        #Merkle of the Elements.
        merkle*: Merkle

#Constructor.
proc newMeritHolderObj*(
    db: DB,
    key: BLSPublicKey
): MeritHolder {.forceCheck: [].} =
    result = MeritHolder(
        db: db,

        key: key,
        keyStr: key.toString(),

        archived: -1,

        signatures: initTable[int, BLSSignature](),
        merkle: newMerkle()
    )
    result.ffinalizeKey()

    #Load our data from the DB.
    try:
        result.archived = result.db.load(result.key)
    except ValueError as e:
        doAssert(false, "Couldn't parse the MeritHolder's archived which was successfully retrieved from the Database: " & e.msg)
    #If we're not in the DB, add ourselves.
    except DBReadError:
        result.db.save(result.key, result.archived)

    #Populate with the info from the DB.
    result.height = result.archived + 1

# [] operator.
proc `[]`*(
    holder: MeritHolder,
    nonce: int
): Element {.forceCheck: [
    IndexError
].} =
    #Check that the nonce isn't out of bounds.
    if nonce >= holder.height:
        raise newException(IndexError, "That MeritHolder doesn't have an Element for that nonce.")

    #Grab it and return it.
    try:
        result = holder.db.load(holder.key, nonce)
    except DBReadError as e:
        doAssert(false, "Couldn't load a Element we were asked for from the Database: " & e.msg)
    return

#Add an Element to the Merkle.
proc addToMerkle*(
    holder: var MeritHolder,
    element: Element
) {.forceCheck: [].} =
    case element:
        of Verification as verif:
            holder.merkle.add(Blake384(verif.serializeSign()))
        else:
            doAssert(false, "Element should be a Verification.")

#Check if an Element is malicious.
#Also checks if the Element already exists.
proc checkMalicious(
    holder: var MeritHolder,
    elem: Element
) {.forceCheck: [
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify they didn't submit two Elements with the same nonce.
    if elem.nonce < holder.height:
        var existing: Element
        try:
            existing = holder[elem.nonce]
        except IndexError as e:
            doAssert(false, "Couldn't grab an Element we're supposed to have: " & e.msg)

        #If this Element was already added, raise DataExists.
        if existing == elem:
            raise newException(DataExists, "Element has already been added.")
        #Else, this is a malicious act.
        else:
            #If this Element is unsigned, this is from a Block. Said Block is invalid.
            #We candnot create a valid MeritRemoval, yet we can include the other Element.
            raise newMaliciousMeritHolder(
                "Block archives an Element which has the same nonce as a different Element.",
                existing
            )
    elif elem.nonce == holder.height:
        discard
    else:
        doAssert(false, "Check Malicious has a gap. This should've been checked for elsewhere.")

proc checkMalicious*(
    holder: var MeritHolder,
    elem: SignedElement
) {.forceCheck: [
    GapError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Make sure there's not a gap.
    if elem.nonce > holder.height:
        raise newException(GapError, "Missing Elements before this SignedElement which was passed to checkMalicious.")

    try:
        holder.checkMalicious(cast[Element](elem))
    except DataExists as e:
        fcRaise e
    except MaliciousMeritHolder as e:
        #Create a Signed Merit Removal.
        var removal: SignedMeritRemoval
        if e.element.nonce <= holder.archived:
            removal = newSignedMeritRemoval(
                true,
                e.element,
                elem,
                elem.signature
            )
        else:
            try:
                removal = newSignedMeritRemoval(
                    false,
                    e.element,
                    elem,
                    signature = @[
                        holder.signatures[e.element.nonce],
                        elem.signature
                    ].aggregate()
                )
            except KeyError as e:
                doAssert(false, "Couldn't get the signature for an Element we know we have the signature for: " & e.msg)
            except BLSError as e:
                doAssert(false, "Failed to aggregate BLS Signatures: " & e.msg)

        raise newMaliciousMeritHolder(
            "MeritHolder submitted two Elements with the same nonce.",
            removal
        )

#Add an Element to a MeritHolder.
proc add*(
    holder: var MeritHolder,
    element: Element
) {.forceCheck: [
    GapError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify we're not missing Elements.
    if element.nonce > holder.height:
        raise newException(GapError, "Missing Elements before this Element.")

    #Check if this Element is malicious.
    try:
        holder.checkMalicious(element)
    except DataExists as e:
        fcRaise e
    except MaliciousMeritHolder as e:
        fcRaise e

    #Increase the height.
    holder.height = holder.height + 1

    #Add the Element to the Merkle.
    holder.addToMerkle(element)

    #Add the Element to the Database.
    holder.db.save(element)

#Add a SignedElement to a MeritHolder.
proc add*(
    holder: var MeritHolder,
    element: SignedElement
) {.forceCheck: [
    ValueError,
    GapError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify the signature.
    try:
        #Don't set the aggregation info for Verifications since we do that before calling checkMalicious.
        if not (element of Verification):
            element.signature.setAggregationInfo(
                newBLSAggregationInfo(element.holder, element.serializeSign())
            )
        if not element.signature.verify():
            raise newException(ValueError, "Failed to verify the Element's signature.")
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        doAssert(false, "Failed to create a BLS Aggregation Info: " & e.msg)

    #Add the Element.
    try:
        holder.add(cast[Element](element))
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MaliciousMeritHolder as e:
        #Manually recreate the Exception since fcRaise wouldn't include the MeritRemoval.
        raise newMaliciousMeritHolder(
            e.msg,
            e.removal
        )

    #Cache the signature.
    holder.signatures[element.nonce] = element.signature

#Slice operators.
proc `[]`*(
    holder: MeritHolder,
    slice: Slice[int]
): seq[Element] {.forceCheck: [
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
        raise newException(IndexError, "Can't get Element Slice from MeritHolder; a was negative.")
    if a > b:
        raise newException(IndexError, "Can't get Element Slice from MeritHolder; b was less than a.")

    #Create a seq.
    result = newSeq[Element](b - a + 1)

    #Grab every Element.
    try:
        for i in a .. b:
            result[i - a] = holder[i]
    except IndexError as e:
        fcRaise e
