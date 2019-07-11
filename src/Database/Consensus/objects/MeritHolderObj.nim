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
    nonce: Natural
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

#Add an Element to a MeritHolder.
proc add*(
    holder: var MeritHolder,
    element: Element
) {.forceCheck: [
    GapError
].} =
    #Verify we're not missing Elements.
    if element.nonce > holder.height:
        raise newException(GapError, "Missing Elements before this Element.")
    #Verify the Element's Nonce.
    elif element.nonce < holder.height:
        doAssert(false, "We are trying to add a Block with invalid records OR MeritHolder.add(SignedElement) did not implement this check.")

    #Increase the height.
    holder.height = holder.height + 1

    #Add the Element to the Merkle.
    case element:
        of Verification as verif:
            holder.merkle.add(Blake384(verif.serializeSign()))
        else:
            doAssert(false, "Element should be a Verification.")

    #Add the Element to the Database.
    holder.db.save(element)

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
            newBLSAggregationInfo(element.holder, element.serializeSign())
        )
        if not element.signature.verify():
            raise newException(ValueError, "Failed to verify the Element's signature.")
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Verify they didn't submit two Elements with the same nonce.
    if element.nonce < holder.height:
        var
            existing: Element
            malicious: bool = false

        try:
            existing = holder[element.nonce]
        except IndexError as e:
            doAssert(false, "Couldn't grab an Element we're supposed to have: " & e.msg)

        #This doesn't use a case statement because of https://github.com/nim-lang/Nim/issues/11711.
        if element of Verification:
            if (not (existing of Verification)) or (cast[Verification](element).hash != cast[Verification](existing).hash):
                malicious = true
        else:
            doAssert(false, "Element should be a Verification.")

        #If the MeritHolder isn't malicious, we already added this Element.
        if not malicious:
            raise newException(DataExists, "Element has already been added.")
        else:
            var
                status: ref MaliciousMeritHolder = newException(MaliciousMeritHolder, "MeritHolder submitted two Elements with the same nonce.")
                signature: BLSSignature

            if existing.nonce <= holder.archived:
                signature = element.signature
            else:
                try:
                    signature = @[
                        holder.signatures[existing.nonce],
                        element.signature
                    ].aggregate()
                except KeyError as e:
                    doAssert(false, "Couldn't get the signature for an Element we know we have the signature for: " & e.msg)
                except BLSError as e:
                    doAssert(false, "Failed to aggregate BLS Signatures: " & e.msg)

            status.removal = cast[pointer](
                newSignedMeritRemoval(
                    holder.archived + 1,
                    existing,
                    element,
                    signature
                )
            )
            raise status

    #Add the Element.
    try:
        holder.add(cast[Element](element))
    except GapError as e:
        fcRaise e

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
