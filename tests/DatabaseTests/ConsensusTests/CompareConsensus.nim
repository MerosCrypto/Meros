#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Compare two Verifications to make sure they have the same value.
proc compare*(
    v1: Verification,
    v2: Verification
) =
    #Test the Entry fields.
    assert(v1.holder == v2.holder)
    assert(v1.nonce == v2.nonce)
    assert(v1.hash == v2.hash)

#Compare two Signed Verifications to make sure they have the same value.
proc compare*(
    v1: SignedVerification,
    v2: SignedVerification
) =
    compare(cast[Verification](v1), cast[Verification](v2))
    assert(v1.signature == v2.signature)
