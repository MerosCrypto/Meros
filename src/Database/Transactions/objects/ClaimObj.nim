#Errors lib.
import ../../../lib/Errors

#Wallet libs.
import ../../../Wallet/Wallet
import ../../../Wallet/MinerWallet

#Transaction object.
import TransactionObj
export TransactionObj

#Mint object.
import MintObj

#Finals lib.
import finals

#Claim object.
finalsd:
    type Claim* = ref object of Transaction
        #BLS Signature that proves the Merit Holder which earned these Mints wants the specified output to receive their reward.
        signature* {.final.}: BLSSignature

#Claim constructor.
func newClaimObj*(
    inputs: varargs[Input],
    output: EdPublicKey
): Claim {.forceCheck: [].} =
    #Create the Claim.
    result = Claim(
        inputs: @inputs,
        outputs: cast[seq[Output]](
            @[
                newClaimOutput(output)
            ]
        )
    )
