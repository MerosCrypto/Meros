#BLS lib.
import ../../../lib/BLS

#Entry object.
import EntryObj

#Finals lib.
import finals

#Claim object.
finalsd:
    type Claim* = ref object of Entry
        #Nonce of the mint being claimed.
        mintNonce* {.final.}: uint
        #BLS Signature that proves you're the person the Mint was to.
        bls* {.final.}: BLSSignature

#New Claim object.
func newClaimObj*(
    mintNonce: uint
): Claim {.raises: [FinalAttributeError].} =
    result = Claim(
        mintNonce: mintNonce
    )
    result.descendant = EntryType.Claim
