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

#Serialize a MemoryVerification.
proc serialize*(verif: MemoryVerification): string {.raises: [ValueError].} =
    result =
        !Address.toBN(verif.sender).toString(256) &
        !verif.hash.toString() &
        !verif.edSignature
