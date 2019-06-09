#Errors lib.
import ../../../lib/Errors

#Verification object.
import ../../Consensus/objects/VerificationObj

#Serialization libs.
import Serialize/Consensus/SerializeVerification
import Serialize/Consensus/ParseVerification

#DB object.
import objects/DBObj
export DBObj

proc get*(
    db: DB,
    key: string
): string {.forceCheck: [].} =
    discard

proc put*(
    db: DB,
    key: string,
    value: string
) {.forceCheck: [].} =
    discard

proc save*(
    db: DB,
    verif: Verification
) {.forceCheck: [].} =
    discard
