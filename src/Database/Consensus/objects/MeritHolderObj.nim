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

#Element objects.
import VerificationObj
import SendDifficultyObj
import DataDifficultyObj
import GasPriceObj
import MeritRemovalObj
import SignedElementObj

#Serialize lib.
import ../../../Network/Serialize/Consensus/SerializeElement

#Finals lib.
import finals

#MeritHolder object.
finalsd:
    type MeritHolder* = ref object
        #DB Function Box.
        db: DB

        #Chain owner.
        key* {.final.}: BLSPublicKey
        keyStr* {.final.}: string

        #MeritHolder height.
        height*: Natural
        #Amount of Elements which have been archived.
        archived*: int
        #seq of the Elements.
        elements*: seq[Element]
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
        elements: @[],
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
        try:
            result.db.save(result.key, result.archived)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a new MeritHolder to the Database: " & e.msg)

    #Populate with the info from the DB.
    result.height = result.archived + 1

# [] operator.
proc `[]`*(
    holder: MeritHolder,
    nonce: Natural
): Element {.forceCheck: [
    IndexError
].} =
    #Check that the nonce isn't out of bounds.
    if nonce >= holder.height:
        raise newException(IndexError, "That MeritHolder doesn't have an Element for that nonce.")

    #If it's in the database...
    if nonce <= holder.archived:
        #Grab it and return it.
        try:
            result = holder.db.load(holder.key, nonce)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Element we were asked for from the Database: " & e.msg)
        return

    #Else, return it from memory.
    result = holder.elements[nonce - (holder.archived + 1)]

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
    #Verify the Element's Nonce.
    elif element.nonce < holder.height:
        #Verify they didn't submit two Elements for the same nonce.
        var existing: Element
        try:
            existing = holder[element.nonce]
        except IndexError as e:
            doAssert(false, "Couldn't grab an Element we're supposed to have: " & e.msg)

        if element of Verification:
            if (not (existing of Verification)) or (cast[Verification](element).hash != cast[Verification](existing).hash):
                raise newException(MaliciousMeritHolder, "MeritHolder submitted two Elements with the same nonce.")
        elif element of SendDifficulty:
            discard
        elif element of DataDifficulty:
            discard
        elif element of GasPrice:
            discard
        elif element of MeritRemoval:
            discard

        #Already added.
        raise newException(DataExists, "Element has already been added.")

    #Increase the height.
    holder.height = holder.height + 1
    #Add the Element to the seq.
    holder.elements.add(element)
    #Add the Element to the Merkle.
    if element of SendDifficulty:
        discard
    elif element of Verification:
        holder.merkle.add(cast[Verification](element).hash)
    elif element of DataDifficulty:
        discard
    elif element of GasPrice:
        discard
    elif element of MeritRemoval:
        discard

    #Add the Element to the Database.
    try:
        holder.db.save(element)
    except DBWriteError as e:
        doAssert(false, "Couldn't save a Element to the Database: " & e.msg)

#Add a SignedElement to a MeritHolder.
proc add*(
    holder: var MeritHolder,
    element: SignedElement
) {.forceCheck: [
    ValueError,
    GapError,
    BLSError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify the signature.
    try:
        element.signature.setAggregationInfo(
            newBLSAggregationInfo(element.holder, element.serializeSignature())
        )
        if not element.signature.verify():
            raise newException(ValueError, "Failed to verify the Element's signature.")
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Add the Element.
    try:
        holder.add(cast[Element](element))
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MaliciousMeritHolder as e:
        fcRaise e

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
    #We would use Natural for this, except `a` can be -1.
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

proc `{}`*(
    holder: MeritHolder,
    slice: Slice[int]
): seq[Element] {.forceCheck: [
    IndexError
].} =
    #Extract the slice values.
    var
        a: int = slice.a
        b: int = slice.b

    if slice.a <= holder.archived:
        raise newException(IndexError, "Signed Slice Operator passed an `a` who's Element no longer has a signature.")

    #Grab the Elements and cast them.
    try:
        result = holder[a .. b]
    except IndexError as e:
        fcRaise e
