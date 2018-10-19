#Base lib.
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Address lib.
import ../../Wallet/Address

#Verification object.
import ../../Database/Merit/objects/VerificationsObj

#Common serialization functions.
import SerializeCommon

#BLS lib.
import ../../lib/BLS

#Serialize a MemoryVerification.
proc serialize*(verif: MemoryVerification): string {.raises: [].} =
    result =
        !verif.verifier.toString() &
        !verif.hash.toString() &
        !verif.signature.toString()
