#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Index object.
import ../../common/objects/IndexObj

#Verification object.
import VerificationObj

#Verifier object.
import VerifierObj

#Tables standard library.
import tables

#Verifications object.
#This was going to be distinct, yet there were performance concerns.
#We were casting to a Table, editing, and then setting the distinct object to the cast of the edited table.
type Verifications* = TableRef[string, Verifier]

#Verifications constructor.
func newVerificationsObj*(): Verifications {.raises: [].} =
    newTable[string, Verifier]()

#Creates a new Verifier on the Verifications.
func add*(
    verifs: Verifications,
    verifier: string
) {.raises: [].} =
    #Make sure the verifier doesn't already exist.
    if verifs.hasKey(verifier):
        return

    #Create a new Verifier.
    verifs[verifier] = newVerifierObj(verifier)

#Gets a Verifier by their key.
func `[]`*(
    verifs: Verifications,
    verifier: string
): Verifier {.raises: [KeyError].} =
    #Call add, which will only create a new Verifier if one doesn't exist.
    verifs.add(verifier)

    #Return the verifier. We can either make Verifications distinct, use this weird format (stopping recursion), or change this operator.
    result = tables.`[]`(verifs, verifier)

#Gets a Verification by its Index.
proc `[]`*(
    verifs: Verifications,
    index: Index
): Verification {.raises: [ValueError].} =
    #Check for the existence of the verifier.
    if not verifs.hasKey(index.key):
        raise newException(ValueError, "Verifications does not have an Verifier for that key.")
    #Check the nonce isn't out of bounds.
    if verifs[index.key].height <= index.nonce:
        raise newException(ValueError, "That verifier doesn't have a Verification for that nonce.")

    result = verifs[index.key][index.nonce]
