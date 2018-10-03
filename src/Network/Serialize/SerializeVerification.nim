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
proc serialize*(verif: Verification): string {.raises: [ValueError].} =
    result =
        !verif.nonce.toString(256) &
        !verif.verified.toBN().toString(256)

    if verif.signature.len != 0:
        result =
            !Address.toBN(verif.sender).toString(256) &
            result &
            !verif.signature
