#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritRemoval object.
import ../../../Database/Consensus/objects/MeritRemovalObj

#Common serialization functions.
import ../SerializeCommon

#SerializeElement method.
import SerializeElement
export SerializeElement

#Serialize Elements methods.
import SerializeVerification

#Serialize a MeritRemoval.
method serialize*(
    mr: MeritRemoval
): string {.forceCheck: [].} =
    result = mr.holder.toBinary()

    if mr.partial:
        result &= "\1"
    else:
        result &= "\0"

    result &=
        mr.element1.serializeRemoval() &
        mr.element2.serializeRemoval()

#Serialize a Signed MeritRemoval.
method signedSerialize*(
    mr: SignedMeritRemoval
): string {.forceCheck: [].} =
    result =
        mr.serialize() &
        mr.signature.toString()
