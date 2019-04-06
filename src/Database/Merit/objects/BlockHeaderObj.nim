#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merkle Tree lib.
import ../../../lib/Merkle

#BLS lib.
import ../../../lib/BLS

#Miners object.
import MinersObj

#Finals lib.
import finals

#String utils standard lib.
import strutils

finalsd:
    #Define the BlockHeader object.
    type BlockHeader* = ref object of RootObj
        #Block Hash.
        hash*: ArgonHash

        #Nonce.
        nonce* {.final.}: uint
        #Argon hash of the last block.
        last* {.final.}: ArgonHash

        #Aggregate Signatue of the Verifications.
        verifications*: BLSSignature
        #Merkle tree hash of the Miners.
        miners: Blake384Hash

        #Timestamp.
        time*: uint
        #Proof.
        proof*: uint

#Calculate the Miners's Merkle Hash.
proc calculateMerkle*(miners: Miners): Blake384Hash {.raises: [ValueError].} =
    #Create a Markle Tree of the Miners.
    var hashes: seq[string] = newSeq[string](miners.len)
    for i in 0 ..< miners.len:
        hashes[i] = Blake384(
            miners[i].miner.toString() &
            miners[i].amount.toBinary()
        ).toString()
    result = newMerkle(hashes).hash.toBlake384Hash()

#Miners accessors.
proc miners*(header: BlockHeader): Blake384Hash {.raises: [].} =
    header.miners

proc `miners=`*(
    header: BlockHeader,
    miners: Blake384Hash
) {.raises: [].} =
    header.miners = miners

proc setMiners(
    header: BlockHeader,
    miners: Miners
) {.raises: [ValueError].} =
    header.miners = miners.calculateMerkle()

proc `miners=`*(
    header: BlockHeader,
    miners: Miners
) {.raises: [ValueError].} =
    header.setMiners(miners)

#Constructor.
proc newBlockHeaderObj*(
    nonce: uint,
    last: ArgonHash,
    verifs: BLSSignature,
    miners: Blake384Hash,
    time: uint,
    proof: uint
): BlockHeader {.raises: [].} =
    result = BlockHeader(
        nonce: nonce,
        last: last,
        verifications: verifs,
        miners: miners,
        time: time,
        proof: proof
    )

    result.ffinalizeNonce()
    result.ffinalizeLast()
