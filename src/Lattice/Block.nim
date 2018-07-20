#Number libs.
import BN
import ../lib/Base

#SHA512 lib.
import ../lib/SHA512 as SHA512File

#Address lib.
import ../Wallet/Address

#Block object.
type Block* = ref object of RootObj
    #Input address. This address for a send block, a different one for a receive block.
    input*: string
    #Output address. This address for a receive block,  different one for a send block.
    output*: string
    #Amount transacted.
    amount*: BN
    #Data included in the TX.
    data*: string
    #Block hash.
    hash: string
    #Difficulty units.
    diffUnits*: int
    #Work to prove this isn't spam.
    work*: BN
    #Lyra2 hash.
    lyra2*: string
    #Block signature.
    signature*: string

proc newBlock*(input: string, output: string, amount: BN, data: string): Block {.raises: [ValueError].} =
    if (not Address.verify(input)) or (not Address.verify(output)):
        raise newException(ValueError, "Block addresses are not valid.")

    if amount < BNNums.ZERO:
        raise newException(ValueError, "Block amount is negative.")

    if data.len > 127:
        raise newException(ValueError, "Block data was too long.")

    result = Block(
        input: input,
        output: output,
        amount: amount,
        data: data,
        hash: (SHA512^2)(
            input.substr(3, input.len).toBN(58).toString(16) &
            output.substr(3, output.len).toBN(58).toString(16) &
            amount.toString(16) &
            data
        ),
        diffUnits: 1 + (2 * data.len)
    )

proc mine*(toMine: Block, difficulty: BN) =
    discard

proc sign*() =
    discard
