#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Transaction object.
import TransactionObj

#Finals lib.
import finals

#Send object.
finalsd:
    type Send* = ref object of Transaction
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
    result = Send()

    #Set the Transaction fields.
    try:
        result.descendant = TransactionType.Send
        result.inputs = inputs
        result.outputs = outputs
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Send: " & e.msg)
