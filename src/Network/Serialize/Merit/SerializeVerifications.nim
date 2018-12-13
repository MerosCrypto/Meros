#Base lib.
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Verification object.
import ../../../Database/Merit/objects/VerificationsObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a MemoryVerification.
func serialize*(verif: MemoryVerification): string {.raises: [].} =
    result =
        !verif.verifier.toString() &
        !verif.hash.toString() &
        !verif.signature.toString()

#Serialize Verifications.
func serialize*(verifs: Verifications): string {.raises: [].} =
    #Add on each verification.
    for verif in verifs.verifications:
        result &=
            #Verifier.
            !verif.verifier.toString() &
            #Hash.
            !verif.hash.toString()
    #We do not add the Aggregate Signature since that is in the Block Header.
