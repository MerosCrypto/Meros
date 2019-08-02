#Errors lib.
import ../../lib/Errors

#MinerWallet lib.
import ../../Wallet/MinerWallet

#MeritRemoval object.
import objects/MeritRemovalObj
export MeritRemovalObj

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
