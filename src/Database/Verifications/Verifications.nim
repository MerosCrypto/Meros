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

#Verification and Verifier lib.
import Verification
import Verifier

#Verifications object.
import objects/Verifications

#Tables standard lib.
import tables

#Finals lib.
import finals

#Add a Verification.
proc add*(
    verifs: Verifications,
    verif: Verification
): bool {.raises: [].} =
    discard

#For each provided Index, archive all Verifications from the account's last archived to the provided nonce.
proc archive*(indexes: seq[Index]) {.raises: [].} =
    discard
