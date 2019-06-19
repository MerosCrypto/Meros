#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import ../../../Database/Consensus/objects/VerificationObj

#Serialize Verification lib.
import SerializeVerification

#SerializeElement method.
import SerializeElement
export SerializeElement

#Serialize a Signed Verification.
method serialize*(
    verif: SignedVerification
): string {.forceCheck: [].} =
    result =
        cast[Verification](verif).serialize() &
        verif.signature.toString()
