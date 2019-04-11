#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#VerificationsIndex object.
import ../../common/objects/VerificationsIndexObj

#Verification object.
import VerificationObj

#Verifier object.
import VerifierObj

#Tables standard lib.
import tables

#Finals lib.
import finals

#Verifications object.
type Verifications* = ref object
    #DB.
    db*: DatabaseFunctionBox
    #List of every Verifier.
    verifiersStr: string

    #Verifier -> Account.
    verifiers: TableRef[string, Verifier]

#Verifications constructor.
proc newVerificationsObj*(
    db: DatabaseFunctionBox
): Verifications {.forceCheck: [].} =
    #Create the Verifications object.
    result = Verifications(
        db: db,
        verifiers: newTable[string, Verifier]()
    )

    #Grab the Verifiers' string, if it exists.
    try:
        result.verifiersStr = result.db.get("verifications_verifiers")
    #If it doesn't, set the Verifiers' string to "",
    except DBReadError:
        result.verifiersStr = ""

    #Create a Verifier for each one in the string.
    for i in countup(0, result.verifiersStr.len - 1, 48):
        #Extract the verifier.
        var verifier: string = result.verifiersStr[i ..< i + 48]

        #Load the Verifier.
        try:
            result.verifiers[verifier] = newVerifierObj(result.db, newBLSPublicKey(verifier))
        except BLSError as e:
            doAssert(false, "Couldn't create a BLS Public Key for a known Verifier: " & e.msg)

#Creates a new Verifier on the Verifications.
proc add(
    verifs: Verifications,
    verifier: BLSPublicKey
) {.forceCheck: [].} =
    #Create a string of the verifier.
    var verifierStr: string = verifier.toString()

    #Make sure the verifier doesn't already exist.
    if verifs.verifiers.hasKey(verifierStr):
        return

    #Create a new Verifier.
    verifs.verifiers[verifierStr] = newVerifierObj(verifs.db, verifier)

    #Add the Verifier to the Verifier's string.
    verifs.verifiersStr &= verifierStr
    #Update the Verifier's String in the DB.
    try:
        verifs.db.put("verifications_verifiers", verifs.verifiersStr)
    except DBWriteError as e:
        doAssert(false, "Couldn't update the Verifiers' string: " & e.msg)

#Gets a Verifier by their key.
proc `[]`*(
    verifs: Verifications,
    verifier: BLSPublicKey
): Verifier {.forceCheck: [].} =
    #Call add, which will only create a new Verifier if one doesn't exist.
    verifs.add(verifier)

    #Return the verifier.
    try:
        result = verifs.verifiers[verifier.toString()]
    except KeyError as e:
        doAssert(false, "Couldn't grab a Verifier despite just calling `add` for that Verifier: " & e.msg)

#Gets a Verification by its Index.
proc `[]`*(
    verifs: Verifications,
    index: VerificationsIndex
): Verification {.forceCheck: [IndexError].} =
    #Check the nonce isn't out of bounds.
    if verifs[index.key].height <= index.nonce:
        raise newException(IndexError, "Verifier doesn't have a Verification for that nonce.")

    try:
        result = verifs.verifiers[index.key.toString()][index.nonce]
    except KeyError as e:
        doAssert(false, "Couldn't grab a Verifier despite just calling `add` for that Verifier: " & e.msg)
    except IndexError as e:
        raise e
