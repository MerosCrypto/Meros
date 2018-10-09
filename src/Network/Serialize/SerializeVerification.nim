#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Address lib.
import ../../Wallet/Address

#Verification object.
import ../../Database/Merit/objects/VerificationObj

#Common serialization functions.
import SerializeCommon

#Serialize a Verification.
proc serialize*(verif: Verification): string {.raises: [ValueError].} =
    result =
        !Address.toBN(verif.sender).toString(256) &
        !verif.hash.toString() &
        !verif.edSignature
