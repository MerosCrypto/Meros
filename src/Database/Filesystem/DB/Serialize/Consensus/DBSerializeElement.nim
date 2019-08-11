#Errors lib.
import ../../../../../lib/Errors

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Element lib.
import ../../../../Consensus/Element

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialize Merit Removal.
import ../../../../../Network/Serialize/Consensus/SerializeMeritRemoval

proc serialize*(
    elem: Element
): string {.forceCheck: [].} =
    case elem:
        of Verification as verif:
            result = char(VERIFICATION_PREFIX) & verif.hash.toString()

        of MeritRemoval as mr:
            result = char(MERIT_REMOVAL_PREFIX) & mr.serialize()

        else:
            doAssert(false, "Failed to serialize an unsupported Element.")
