#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Index object.
import ../../common/objects/IndexObj

#Verifications lib.
import ../../Verifications/Verifications

#Block Header and Miners objects.
import BlockHeaderObj
import MinersObj

#Serialization libs.
import ../../../Network/Serialize/Merit/SerializeBlockHeader
import ../../../Network/Serialize/Merit/SerializeMiners

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Define the Block class.
type Block* = ref object of RootObj
    #Block Header.
    header*: BlockHeader
    #Hash of the Block Header.
    hash*: ArgonHash

    #Verifications.
    verifications*: seq[Index]
    #Who to attribute the Merit to (amount is 0 (exclusive) to 100 (inclusive)).
    miners*: Miners

#Set the Miners.
proc `miners=`*(newBlock: Block, miners: Miners) =
    newBlock.miners = miners
    newBlock.header.miners = miners

#Constructor.
proc newBlockObj*(
    verifs: Verifications,
    nonce: uint,
    last: ArgonHash,
    indexes: seq[Index],
    miners: Miners,
    time: uint,
    proof: uint = 0
): Block {.raises: [ValueError, ArgonError, BLSError].} =
    #Create the Block.
    result = Block(
        header: newBlockheaderObj(
            nonce,
            last,
            nil,
            miners.calculateMerkle(),
            time,
            proof
        ),
        verifications: indexes,
        miners: miners
    )

    if indexes.len > 0:
        #Set the verifications aggregate signature.
        var signatures: seq[BLSSignature]
        for index in indexes:
            signatures.add(
                verifs[index.key]{verifs[index.key].archived .. index.nonce}.calculateSig()
            )
        result.header.verifications = signatures.aggregate()

    #Set the Header hash.
    result.hash = Argon(result.header.serialize(), result.header.proof.toBinary())
