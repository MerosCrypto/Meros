#Numerical libs.
import BN
import ../../../lib/Base

#Node object.
import NodeObj

#Data object.
type Data* = ref object of Node
    #Data included in the TX.
    data: seq[uint8]
    #SHA512 hash.
    sha512: string
    #Proof this isn't spam.
    proof: BN

#New Data object.
proc newDataObj*(data: seq[uint8]): Data {.raises: [].} =
    Data(
        descendant: NodeType.Data,
        data: data
    )

#Set the SHA512 hash.
proc setSHA512*(data: Data, sha512: string): bool =
    result = true
    if data.sha512.len != 0:
        return false

    data.sha512 = sha512

#Set the proof.
proc setProof*(data: Data, proof: BN): bool =
    result = true
    if not data.proof.getNil():
        return false

    data.proof = proof

#Getters.
proc getData*(data: Data): seq[uint8] {.raises: [].} =
    data.data
proc getSHA512*(data: Data): string {.raises: [].} =
    data.sha512
proc getProof*(data: Data): BN {.raises: [].} =
    data.proof
