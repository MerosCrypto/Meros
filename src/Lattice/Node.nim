#Number libs.
import BN
import ../lib/Base

#SHA512 lib.
import ../lib/SHA512 as SHA512File
import ../lib/Util

#Wallet libs.
import ../Wallet/Wallet

#Node object.
type Node* = ref object of RootObj
    #Data used to create the hash.
    #Input address. This address for a send node, a different one for a receive node.
    input*: string
    #Output address. This address for a receive node,  different one for a send node.
    output*: string
    #Amount transacted.
    amount*: BN
    #Data included in the TX.
    data*: string
    #Node hash.
    hash: string

    #Data used to prove it isn't spam.
    #Difficulty units.
    diffUnits*: BN
    #Work to prove this isn't spam.
    work*: BN
    #Lyra2 hash.
    lyra2*: string

    #Data proved to validate ownership.
    #Node signature.
    signature*: string

    #Metadata about when the TX was accepted.
    time*: BN

proc newNode*(input: string, output: string, amount: BN, data: string): Node {.raises: [ValueError, Exception].} =
    if (not Wallet.verify(input)) or (not Wallet.verify(output)):
        raise newException(ValueError, "Node addresses are not valid.")

    if amount < BNNums.ZERO:
        raise newException(ValueError, "Node amount is negative.")

    if data.len > 127:
        raise newException(ValueError, "Node data was too long.")

    result = Node(
        input: input,
        output: output,
        amount: amount,
        data: data,
        hash: (SHA512^2)(
            input.substr(3, input.len).toBN(58).toString(16) &
            output.substr(3, output.len).toBN(58).toString(16) &
            amount.toString(16) &
            data
        )
    )

proc mine*(toMine: Node, networkDifficulty: BN) {.raises: [].} =
    toMine.diffUnits = newBN(1 + (toMine.data.len * 2))

    var difficulty: BN = toMine.diffUnits * networkDifficulty


proc sign*(wallet: Wallet, toSign: Node): bool {.raises: [ValueError, Exception].} =
    var newNode: Node
    try:
        newNode = newNode(
            toSign.input,
            toSign.output,
            toSign.amount,
            toSign.data,
        )
    except:
        return false

    if toSign.hash != newNode.hash:
        return false

    if toSign.diffUnits != newBN(1 + (2 * toSign.data.len)):
        return false

    #Verify work and Lyra2.

    toSign.signature = wallet.sign(toSign.lyra2)
    return true
