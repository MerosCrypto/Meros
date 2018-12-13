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
        verifications*: BLSSignature
        #Merkle tree hash of the Miners.
        miners*: SHA512Hash

        #Timestamp.
        time*: uint

#Set Verifications function.
proc setVerifications*(
    header: BlockHeader,
    verifications: Verifications
) {.raises: [].} =
    header.verifications = verifications.aggregate

#Calculate the Miners's Merkle Hash.
proc calculateMerkle*(miners: Miners): SHA512Hash {.raises: [].} =
    #Create a Markle Tree of the Miners.
    var hashes: seq[SHA512Hash] = newSeq[SHA512Hash](miners.len)
    for i in 0 ..< miners.len:
        hashes[i] = SHA512(
            miners[i].miner.toString() &
            miners[i].amount.toBinary()
        )
    result = newMerkleTree(hashes).hash

#Set Miners function.
proc setMiners*(
    header: BlockHeader,
    miners: Miners
) {.raises: [].} =
    header.miners = miners.calculateMerkle()

#Constructor.
proc newBlockHeaderObj*(
    nonce: uint,
    last: ArgonHash,
    verifications: Verifications,
    miners: Miners,
    time: uint,
): BlockHeader {.raises: [].} =
    #Create the Block Header.
    result = BlockHeader(
        nonce: nonce,
        last: last,
        time: time
    )
    result.ffinalizeNonce()
    result.ffinalizeLast()

    #Set the Verifications.
    result.setVerifications(verifications)

    #Set the Miners.
    result.setMiners(miners)
