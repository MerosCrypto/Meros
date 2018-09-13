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

#SetOnce lib.
import SetOnce

#Serialize a Verification.
proc serialize*(verif: Verification): string {.raises: [ValueError, Exception].} =
    result =
        verif.nonce.toString(255) !
        verif.verified.toBN().toString(255)

    if verif.signature.len != 0:
        result =
            Address.toBN(verif.sender).toString(255) !
            result !
            verif.signature.toBN(16).toString(255)

        result = result.toBN(256).toString(253)
