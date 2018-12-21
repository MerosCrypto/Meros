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

#Wallet lib.
import ../../../Wallet/Wallet

#Verifications and Miners objects.
import VerificationsObj
import MinersObj

#Finals lib.
import finals

#String utils standard lib.
import strutils

finalsd:
    #Define the BlockHeader object.
    type BlockHeader* = ref object of RootObj
        #Nonce.
        nonce* {.final.}: uint
        #Argon hash of the last block.
        last* {.final.}: ArgonHash

        #Aggregate Signatue of the Verifications.
        verifications: BLSSignature
        #Merkle tree hash of the Miners.
        miners: SHA512Hash

        #Timestamp.
        time*: uint

#Verifications accessors.
proc verifications*(header: BlockHeader): BLSSignature =
    header.verifications

proc `verifications=`*(
    header: BlockHeader,
    verifications: BLSSignature
) {.raises: [].} =
    header.verifications = verifications

proc setVerifications(
    header: BlockHeader,
    verifications: Verifications
) {.raises: [].} =
    header.verifications = verifications.aggregate

proc `verifications=`*(
    header: BlockHeader,
    verifications: Verifications
) {.raises: [].} =
    header.setVerifications(verifications)

#Calculate the Miners's Merkle Hash.
proc calculateMerkle*(miners: Miners): SHA512Hash {.raises: [ValueError].} =
    #Create a Markle Tree of the Miners.
    var hashes: seq[string] = newSeq[string](miners.len)
    for i in 0 ..< miners.len:
        hashes[i] = SHA512(
            miners[i].miner.toString() &
            miners[i].amount.toBinary()
        ).toString()
    result = newMerkle(hashes).hash.toSHA512Hash()

#Miners accessors.
proc miners*(header: BlockHeader): SHA512Hash {.raises: [].} =
    header.miners

proc `miners=`*(
    header: BlockHeader,
    miners: SHA512Hash
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

#Constructors.
proc newBlockHeaderObj*(
    nonce: uint,
    last: ArgonHash,
    verifications: BLSSignature,
    miners: SHA512Hash,
    time: uint,
): BlockHeader {.raises: [].} =
    #Create the Block Header.
    result = BlockHeader(
        nonce: nonce,
        last: last,
        verifications: verifications,
        miners: miners,
        time: time
    )
    result.ffinalizeNonce()
    result.ffinalizeLast()

proc newBlockHeaderObj*(
    nonce: uint,
    last: ArgonHash,
    verifications: Verifications,
    miners: Miners,
    time: uint,
): BlockHeader {.raises: [ValueError].} =
    newBlockHeaderObj(
        nonce,
        last,
        verifications.aggregate,
        miners.calculateMerkle(),
        time
    )
