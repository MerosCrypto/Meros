#Errors lib.
import ../../../../lib/Errors

#Hash lib.
import ../../../../lib/Hash

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element object.
import ElementObj

#VerificationPacket objects.
type
    VerificationPacket* = ref object of Element
        holders*: seq[uint16]
        hash*: Hash[256]

    MeritRemovalVerificationPacket* = ref object of Element
        holders*: seq[BLSPublicKey]
        hash*: Hash[256]

    SignedVerificationPacket* = ref object of VerificationPacket
        signature*: BLSSignature

#Constructors.
func newVerificationPacketObj*(
    hash: Hash[256]
): VerificationPacket {.inline, forceCheck: [].} =
    VerificationPacket(
        hash: hash
    )

func newMeritRemovalVerificationPacketObj*(
    hash: Hash[256]
): MeritRemovalVerificationPacket {.inline, forceCheck: [].} =
    MeritRemovalVerificationPacket(
        hash: hash
    )

func newSignedVerificationPacketObj*(
    hash: Hash[256]
): SignedVerificationPacket {.inline, forceCheck: [].} =
    SignedVerificationPacket(
        hash: hash
    )
