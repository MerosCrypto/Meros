#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Index object.
import ../../common/objects/IndexObj

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Verification object.
import VerificationObj

#Verifier object.
import VerifierObj

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Finals lib.
import finals

#Verifications object.
type Verifications* = ref object
    db*: DatabaseFunctionBox
    verifiersSeq: seq[string]
    verifiersStr: string

    verifiers: TableRef[string, Verifier]

#Verifications constructor.
proc newVerificationsObj*(db: DatabaseFunctionBox): Verifications {.raises: [].} =
    #Create the Verifications object.
    result = Verifications(
        db: db,
        verifiers: newTable[string, Verifier]()
    )

    #Grab the Verifiers' string, if it exists.
    try:
        result.verifiersStr = result.db.get("verifications_verifiers")
        result.verifiersSeq = newSeq[string](result.verifiersStr.len div 48)

        #Create a Verifier for each one in the string.
        for i in countup(0, result.verifiersStr.len, 48):
            #Extract the verifier.
            var verifier = result.verifiersStr[i .. i + 47].strip()

            #Store it in the seq.
            result.verifiersSeq[i div 48] = verifier

            #Load the Verifier.
            result.verifiers[verifier] = newVerifierObj(verifier, result.db)
    #If it doesn't, set the Verifiers' string to "",
    except:
        result.verifiersStr = ""
        result.verifiersSeq = @[]

#Creates a new Verifier on the Verifications.
proc add(
    verifs: Verifications,
    verifier: string
) {.raises: [LMDBError].} =
    #Make sure the verifier doesn't already exist.
    if verifs.verifiers.hasKey(verifier):
        return

    #Create a new Verifier.
    verifs.verifiers[verifier] = newVerifierObj(verifier, verifs.db)

    #Check if this Verifier is already in the DB.
    if not verifs.verifiersSeq.contains(verifier):
        #Add the Verifier to the Verifier's string and seq.
        verifs.verifiersStr &= verifier.pad(48)
        verifs.verifiersSeq.add(verifier)
        #Update the Verifier's String in the DB.
        verifs.db.put("verifications_verifiers", verifs.verifiersStr)

#Gets a Verifier by their key.
proc `[]`*(
    verifs: Verifications,
    verifier: string
): Verifier {.raises: [KeyError, LMDBError].} =
    #Call add, which will only create a new Verifier if one doesn't exist.
    verifs.add(verifier)

    #Return the verifier.
    result = verifs.verifiers[verifier]

#Gets a Verification by its Index.
proc `[]`*(
    verifs: Verifications,
    index: Index
): Verification {.raises: [ValueError, BLSError, LMDBError, FinalAttributeError].} =
    #Check for the existence of the verifier.
    if not verifs.verifiers.hasKey(index.key):
        raise newException(ValueError, "Verifications does not have an Verifier for that key.")
    #Check the nonce isn't out of bounds.
    if verifs.verifiers[index.key].height <= index.nonce:
        raise newException(ValueError, "That verifier doesn't have a Verification for that nonce.")

    result = verifs.verifiers[index.key][index.nonce]

#Iterate over every verifier.
iterator verifiers*(verifs: Verifications): string {.raises: [].} =
    for verifier in verifs.verifiers.keys():
        yield verifier
