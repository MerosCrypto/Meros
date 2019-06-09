#Errors lib.
import ../../lib/Errors

#Verification object.
import ../Consensus/objects/VerificationObj

#Serialization libs.
import ../../Network/Serialize/Merit/SerializeVerification
import ../../Network/Serialize/Merit/ParseVerification

#DB lib.
import DB

proc save*(
    db: DB,
    verif: Verification
): {.forceCheck: [].} =
    discard
