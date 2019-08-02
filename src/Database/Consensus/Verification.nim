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
import ../../Network/Serialize/Consensus/SerializeVerification

#Sign a Verification.
proc sign*(
    miner: MinerWallet,
    verif: SignedVerification,
    nonce: int
) {.forceCheck: [
    BLSError
].} =
    try:
        #Set the holder.
        verif.holder = miner.publicKey
        #Set the nonce.
        verif.nonce = nonce
        #Sign the hash of the Verification.
        try:
            verif.signature = miner.sign(verif.serializeSign())
        except BLSError as e:
            fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Verification: " & e.msg)
