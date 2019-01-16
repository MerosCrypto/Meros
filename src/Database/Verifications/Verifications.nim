#Errors.
import ../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#Index object.
import ../common/objects/IndexObj

#VerifierIndex object (not under common as this is solely used for archival, which is triggered by Merit).
import ../Merit/objects/VerifierIndexObj

#Verification and Verifier libs.
import Verification
import Verifier
export Verification
export Verifier

#Verifications object.
import objects/VerificationsObj
export VerificationsObj

#Tables standard lib.
import tables

#Finals lib.
import finals

proc newVerifications*(): Verifications =
    newVerificationsObj()

#Add a Verification.
proc add*(
    verifs: Verifications,
    verif: Verification
) {.raises: [KeyError, MerosIndexError].} =
    if not verifs.hasKey(verif.verifier.toString()):
        verifs[verif.verifier.toString()] = newVerifierObj(verif.verifier.toString())

    verifs[verif.verifier.toString()].add(verif)

#For each provided Index, archive all Verifications from the account's last archived to the provided nonce.
proc archive*(verifs: Verifications, indexes: seq[VerifierIndex], archived: uint) {.raises: [KeyError, FinalAttributeError].} =
    #Declare the start variable outside of the loop.
    var start: uint

    #Iterate over every Index.
    for index in indexes:
        #Calculate the start.
        start = verifs[index.key].archived + 1
        #Iterate over every Verification.
        for i in start .. index.nonce:
            #Archive the Verification.
            verifs[index.key][i].archived = archived

        #Update the Verifier.
        verifs[index.key].archived = index.nonce
