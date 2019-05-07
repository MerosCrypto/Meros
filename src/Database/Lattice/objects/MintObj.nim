#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Entry object.
import EntryObj

#Finals lib.
import finals

#Mint object.
finalsd:
    type Mint* = ref object of Entry
        #Destination key.
        output* {.final.}: BLSPublicKey
        #Amount transacted.
        amount* {.final.}: uint64

#Constructor.
func newMintObj*(
    output: BLSPublicKey,
    amount: uint64
): Mint {.forceCheck: [].} =
    #Set the Mint fields.
    result = Mint(
        output: output,
        amount: amount
    )
    result.ffinalizeOutput()
    result.ffinalizeAmount()

    #Set the constant entry fields.
    try:
        result.descendant = EntryType.Mint
        result.verified = true
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
