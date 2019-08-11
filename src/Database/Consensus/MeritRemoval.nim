#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#MeritRemoval object.
import objects/MeritRemovalObj
export MeritRemovalObj

#MeritRemoval serialize libs.
import ../../Network/Serialize/SerializeCommon
import ../../Network/Serialize/Consensus/SerializeMeritRemoval

func newMeritRemoval*(
    nonce: int,
    element1: Element,
    element2: Element
): MeritRemoval {.inline, forceCheck: [].} =
    newMeritRemovalObj(
        nonce,
        element1,
        element2
    )

func newSignedMeritRemoval*(
    nonce: int,
    element1: Element,
    element2: Element,
    signature: BLSSignature
): SignedMeritRemoval {.inline, forceCheck: [].} =
    newSignedMeritRemovalObj(
        nonce,
        element1,
        element2,
        signature
    )

proc merkle*(
    mr: MeritRemoval
): Hash[384] {.forceCheck: [].} =
    result = Blake384(char(MERIT_REMOVAL_PREFIX) & mr.serialize())
