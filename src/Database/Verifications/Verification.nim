#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Verification object.
import objects/VerificationObj
export VerificationObj

#Serialize lib.
import ../../Network/Serialize/Verifications/SerializeVerification

#Sign a Verification.
proc sign*(
    miner: MinerWallet,
    verif: MemoryVerification,
    nonce: Natural
) {.forceCheck: [
    BLSError
].} =
    try:
        #Set the verifier.
        verif.verifier = miner.publicKey
        #Set the nonce.
        verif.nonce = nonce
        #Sign the hash of the Verification.
        try:
            verif.signature = miner.sign(cast[Verification](verif).serialize())
        except BLSError as e:
            fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Verification: " & e.msg)
