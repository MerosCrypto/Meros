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
        proof* {.final.}: int
        #Argon hash.
        argon* {.final.}: ArgonHash

#Send constructor.
func newSendObj*(
    inputs: seq[SendInput],
    outputs: seq[SendOutput]
): Send {.forceCheck: [].} =
    #Sreate the Send.
    result = Send(
        inputs: cast[seq[Input]](inputs),
        outputs: cast[seq[Output]](outputs)
    )

    #Set the Transaction fields.
    try:
        result.descendant = TransactionType.Send
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Send: " & e.msg)
