#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

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

        #Create a Verifier for each one in the string.
        for i in countup(0, result.verifiersStr.len - 1, 48):
            #Extract the verifier.
            var verifier: string = result.verifiersStr[i ..< i + 48]

            #Load the Verifier.
            result.verifiers[verifier] = newVerifierObj(result.db, verifier)
    #If it doesn't, set the Verifiers' string to "",
    except:
        result.verifiersStr = ""

#Creates a new Verifier on the Verifications.
proc add(
    verifs: Verifications,
    verifier: string
) {.raises: [].} =
    #Make sure the verifier doesn't already exist.
    if verifs.verifiers.hasKey(verifier):
        return

    #Create a new Verifier.
    verifs.verifiers[verifier] = newVerifierObj(verifs.db, verifier)

    #Add the Verifier to the Verifier's string.
    verifs.verifiersStr &= verifier
    #Update the Verifier's String in the DB.
    try:
        verifs.db.put("verifications_verifiers", verifs.verifiersStr)
    except DBError as e:
        doAssert(false, "Couldn't update the Verifiers' string: " & e.msg)

#Gets a Verifier by their key.
proc `[]`*(
    verifs: Verifications,
    verifier: string
): Verifier {.raises: [].} =
    #Call add, which will only create a new Verifier if one doesn't exist.
    verifs.add(verifier)

    #Return the verifier.
    try:
        result = verifs.verifiers[verifier]
    except KeyError as e:
        doAssert(false, "Couldn't load a Verifier despite just calling `add` for that Verifier: " & e.msg)

#Gets a Verification by its Index.
proc `[]`*(
    verifs: Verifications,
    index: Index
): Verification {.raises: [ValueError, BLSError, DBError, FinalAttributeError].} =
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
