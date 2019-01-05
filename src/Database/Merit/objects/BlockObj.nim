#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Block Header, Verifications, and Miners objects.
import BlockHeaderObj
import VerificationsObj
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

#Set the Verifications.
proc setVerifications(data: Block, verifications: Verifications, indexes: seq[Index]) {.raises: [ValueError].} =
    #Verify the indexes.
    for index in indexes:
        if not verifications.hasKey(index.key):
            raise newException(ValueError, "Invalid verifier.")

        if index.nonce <= verifications[index.key].archived:
            raise newException(ValueError, "Nonce already archived.")

        if index.nonce >= verifications[index.key].len:
            raise newException(ValueError, "Archiving non-existant Verifications.")
    data.verifications = indexes

    #Caclulate the aggregate.
    var signatures: seq[BLSSignature]
    for index in indexes:
        signatures.add(
            verifications[verifier][verifications[verifier].archived .. index.nonce].calculateSig()
        )
    result.header.verifications = signatures.calculateSig()

#Set the Miners.
proc `miners=`*(newBlock: Block, miners: Miners) =
    newBlock.miners = miners
    newBlock.header.miners = miners

#Constructor.
proc newBlockObj*(
    nonce: uint,
    last: ArgonHash,
    verifications: seq[Index],
    miners: Miners,
    time: uint,
    proof: uint = 0
): Block {.raises: [ValueError, ArgonError].} =
    #Create the Block.
    result = Block(
        header: newBlockheaderObj(
            nonce,
            last,
            miners,
            time,
            proof
        ),
        verifications: verifications,
        miners: miners
    )

    #Set the Header hash.
    result.hash = Argon(result.header.serialize())
