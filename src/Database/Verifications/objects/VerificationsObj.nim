#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Merit lib.
import ../../Merit/Merit

#Index object.
import ../../common/objects/IndexObj

#Verification object.
import VerificatonObj

#Verifier object.
import VerifierObj

#Tables standard library.
import tables

#Verifications object.
#This was going to be distinct, yet there were performance concerns.
#We were casting to a Table, editing, and then setting the distinct object to the cast of the edited table.
type Verifications* = TableRef[string, Verifier]

#Verifications constructor.
func newVerifications*(): Verifications {.raises: [ValueError].} =
    newTable[string, Verifier]()

#Creates a new Verifier on the Verifications.
func add*(
    verifications: Verifications,
    verifier: string
) {.raises: [].} =
    #Make sure the verifier doesn't already exist.
    if verifications.hasKey(verifier):
        return

    #Create a new Verifier.
    verifications[verifier] = newVerifierObj(verifier)

#Gets a Verifier by their key.
func `[]`*(
    verifications: Verifications,
    verifier: string
): Verifier {.raises: [ValueError].} =
    #Call add, which will only create a new Verifier if one doesn't exist.
    verifications.add(verifier)

    #Return the verifier.
    result = verifications[verifier]

#Gets a Verification by its Index.
proc `[]`*(
    Verifications: Verifications,
    index: Index
): Verification {.raises: [ValueError].} =
    #Check for the existence of the verifier.
    if not verifications.hasKey(index.key):
        raise newException(ValueError, "Verifications does not have an Verifier for that key.")
    #Check the nonce isn't out of bounds.
    if verifications[index.key].height <= index.nonce:
        raise newException(ValueError, "That verifier doesn't have a Verification for that nonce.")

    result = verifications[verifier][index.nonce]
