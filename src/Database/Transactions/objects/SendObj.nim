#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Transaction object.
import TransactionObj
export TransactionObj

#Send object.
type Send* = ref object of Transaction
    #Signature.
    signature*: EdSignature
    #Proof this isn't spam.
    proof*: uint32
    #Argon hash.
    argon*: ArgonHash

#Send constructor.
func newSendObj*(
    inputs: varargs[FundedInput],
    outputs: varargs[SendOutput]
): Send {.forceCheck: [].} =
    #Sreate the Send.
    result = Send(
        inputs: cast[seq[Input]](@inputs),
        outputs: cast[seq[Output]](@outputs)
    )
