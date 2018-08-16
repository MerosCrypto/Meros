#Numerical libs.
import ../../../lib/BN
import ../../../lib/Base

#Node object.
import NodeObj

#Transaction object.
type Transaction* = ref object of Node
    #Data used to create the SHA512 hash.
    #Input address. This address for a send node, a different one for a receive node.
    input: string
    #Output address. This address for a receive node, a different one for a send node.
    output: string
    #Amount transacted.
    amount: BN
    #Data included in the TX.
    data: seq[uint8]

    #SHA512 hash.
    sha512: string

    #Data used to prove it isn't spam.
    #Difficulty units.
    diffUnits: BN
    #Proof this isn't spam.
    proof: BN

#New Transaction object.
proc newTransactionObj*(input: string, output: string, amount: BN, data: seq[uint8]): Transaction {.raises: [].} =
    Transaction(
        input: input,
        output: output,
        amount: amount,
        data: data,

        diffUnits: newBN(1 + (2 * data.len))
    )

#Set the SHA512 hash.
proc setSHA512*(tx: Transaction, sha512: string): bool =
    result = true
    if not ((tx.sha512.isNil) or (not sha512.isBase(16))):
        result = false
        return

    tx.sha512 = sha512

#Set the proof.
proc setProof*(tx: Transaction, proof: BN): bool =
    result = true
    if not tx.proof.isNil:
        result = false
        return

    tx.proof = proof

#Getters.
proc getInput*(tx: Transaction): string {.raises: [].} =
    tx.input
proc getOutput*(tx: Transaction): string {.raises: [].} =
    tx.output
proc getAmount*(tx: Transaction): BN {.raises: [].} =
    tx.amount
proc getData*(tx: Transaction): seq[uint8] {.raises: [].} =
    tx.data
proc getSHA512*(tx: Transaction): string {.raises: [].} =
    tx.sha512
proc getDiffUnits*(tx: Transaction): BN {.raises: [].} =
    tx.diffUnits
proc getProof*(tx: Transaction): BN {.raises: [].} =
    tx.proof
