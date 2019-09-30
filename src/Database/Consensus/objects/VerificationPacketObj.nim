#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

#VerificationPacket objects.
finalsd:
    type
        VerificationPacket* = ref object of RootObj
            holders*: seq[uint32]
            hash* {.final.}: Hash[384]

        SignedVerificationPacket* = ref object of VerificationPacket
            signatures*: seq[BLSSignature]
            signature*: BLSSignature

#Constructors.
func newVerificationPacketObj*(
    hash: Hash[384]
): VerificationPacket {.forceCheck: [].} =
    result = VerificationPacket(
        hash: hash
    )
    result.ffinalizeHash()

func newSignedVerificationPacketObj*(
    hash: Hash[384]
): SignedVerificationPacket {.forceCheck: [].} =
    result = SignedVerificationPacket(
        hash: hash
    )
    result.ffinalizeHash()
