#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritRemoval object.
import ../../../Database/Consensus/Elements/objects/MeritRemovalObj

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
    result = mr.holder.toBinary().pad(NICKNAME_LEN)

    if mr.partial:
        result &= "\1"
    else:
        result &= "\0"

    result &=
        mr.element1.serializeWithoutHolder() &
        mr.element2.serializeWithoutHolder()

#Serialize a MeritRemoval for inclusion in a BlockHeader's contents merkle.
method serializeContents*(
    mr: MeritRemoval
): string {.inline, forceCheck: [].} =
    char(MERIT_REMOVAL_PREFIX) &
    mr.serialize()

#Serialize a Signed MeritRemoval.
method signedSerialize*(
    mr: SignedMeritRemoval
): string {.inline, forceCheck: [].} =
    mr.serialize() &
    mr.signature.toString()
