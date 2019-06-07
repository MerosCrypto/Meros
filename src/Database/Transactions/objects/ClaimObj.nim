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
        bls* {.final.}: BLSSignature

#Claim constructor.
func newClaimObj*(
    mints: seq[Mint],
    output: EdPublicKey
): Claim {.forceCheck: [].} =
    #Create the Claim inputs and output amount.
    var
        inputs: seq[Input] = @[]
        amount: uint64 = 0
    for mint in mints:
        result.inputs.add(newInput(mint.hash))
        amount += mint.outputs[0].amount

    #Create the Claim.
    result = Claim(
        inputs: inputs,
        outputs: cast[seq[Output]](
            @[
                newSendOutput(
                    output,
                    amount
                )
            ]
        )
    )

    #Set the Transaction fields.
    try:
        result.descendant = TransactionType.Claim
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Claim: " & e.msg)
