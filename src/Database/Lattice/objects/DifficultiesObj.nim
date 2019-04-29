#Errors lib.
import ../../../lib/Errors

#BN/Hex lib.
import ../../../lib/Hex

type
    Difficulties* = object
        send*: BN
        data*: BN

proc newDifficultiesObj*(
    sendArg: string,
    dataArg: string
): Difficulties {.forceCheck: [].} =
    try:
        result = Difficulties(
            send: sendArg.toBNFromHex(),
            data: dataArg.toBNFromHex()
        )
    except ValueError as e:
        doAssert(false, "Invalid Lattice Difficulties: " & e.msg)
