#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Type stub.
type VerificationPacket* = object
    verifiers*: seq[int]
