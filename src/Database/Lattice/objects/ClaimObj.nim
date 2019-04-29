#Errors lib.
import ../../../lib/Errors

#MinerWallet lib (for BLSSignature).
import ../../../Wallet/MinerWallet

#Entry object.
import EntryObj

#Finals lib.
import finals

#Claim object.
finalsd:
    type Claim* = ref object of Entry
        #Nonce of the mint being claimed.
        mintNonce* {.final.}: int
        #BLS Signature that proves you're the person the Mint was to.
        bls* {.final.}: BLSSignature

#New Claim object.
func newClaimObj*(
    mintNonce: Natural
): Claim {.forceCheck: [].} =
    result = Claim(
        mintNonce: mintNonce
    )
    result.ffinalizeMintNonce()

    try:
        result.descendant = EntryType.Claim
    except FinalAttributeError as e:
        doAssert(false, "Set a final ~attribute twice when creating a Claim: " & e.msg)
