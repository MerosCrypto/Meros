#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Transaction object.
import TransactionObj
export TransactionObj

#Finals lib.
import finals

#Send object.
finalsd:
    type Send* = ref object of Transaction
        #Signature.
        signature* {.final.}: EdSignature
        #Proof this isn't spam.
        proof* {.final.}: uint32
        #Argon hash.
        argon* {.final.}: ArgonHash

#Send constructor.
func newSendObj*(
    inputs: varargs[SendInput],
    outputs: varargs[SendOutput]
): Send {.forceCheck: [].} =
    #Sreate the Send.
    result = Send(
        inputs: cast[seq[Input]](@inputs),
        outputs: cast[seq[Output]](@outputs)
    )
