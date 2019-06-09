#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

type
    Difficulties* = object
        send*: Hash[384]
        data*: Hash[384]

proc newDifficultiesObj*(
    sendArg: string,
    dataArg: string
): Difficulties {.forceCheck: [].} =
    try:
        result = Difficulties(
            send: sendArg.toHash(384),
            data: dataArg.toHash(384)
        )
    except ValueError as e:
        doAssert(false, "Invalid Transactions Difficulties: " & e.msg)
