#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Transaction object.
import TransactionObj

#Finals lib.
import finals

#Claim object.
finalsd:
    type Claim* = ref object of Transaction
        #BLS Signature that proves the Merit Holder which earned these Mints wants th specified key to receive their reward.
        bls: BLSSignature

#Claim constructor.
func newClaimObj*(
    mints: seq[Mint],
    key: EdPublicKey
): Claim {.forceCheck: [].} =
    #Create the Claim.
    result = Claim()

    #Create the Claim inputs and output amount.
    var
        inputs: seq[Input] = @[]
        amount: uint64 = 0
    for mint in mints:
        result.inputs.add(mint.hash)
        amount += mint.outputs[0].amount

    #Set the Transaction fields.
    try:
        result.descendant = TransactionType.Claim
        result.inputs = inputs
        result.outputs = @[
            SendOutput(
                key: key,
                amount: amount
            )
        ]
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Claim: " & e.msg)
