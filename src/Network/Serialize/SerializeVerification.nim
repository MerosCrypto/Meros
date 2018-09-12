#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Address lib.
import ../../Wallet/Address

#Node and Verification object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/VerificationObj

#Common serialization functions.
import SerializeCommon

#Serialize a Verification.
proc serialize*(verif: Verification): string {.raises: [ValueError, Exception].} =
    result =
        verif.getNonce().toString(255) !
        verif.getVerified().toBN().toString(255)

    if verif.getSignature().len != 0:
        result =
            Address.toBN(verif.getSender()).toString(255) !
            result !
            verif.getSignature().toBN(16).toString(255)

        result = result.toBN(256).toString(253)
