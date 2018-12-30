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
    #Random number to prove work was done.
    proof*: uint
    #Header Hash.
    hash*: SHA512Hash
    #Argon2d hash (Argon2d(hash, proof) must be greater than the difficulty).
    argon*: ArgonHash

    #Verifications.
    verifications*: seq[Index]
    #Who to attribute the Merit to (amount ranges from 0 to 100).
    miners*: Miners

#Constructor.
proc newBlockObj*(
    nonce: uint,
    last: ArgonHash,
    verifications: Verifications,
    miners: Miners,
    proof: uint,
    time: uint
): Block {.raises: [ValueError, ArgonError].} =
    #Create the Block.
    result = Block(
        header: newBlockheaderObj(
            nonce,
            last,
            miners,
            time
        ),
        proof: proof,
        miners: miners
    )

    #Calculate who has new Verifications.
    var indexes: seq[Index] = @[]
    for verifier in verifications.keys():
        if verifications[verifier].archived != verifications[verifier].height - 1:
            indexes.push(newIndex(verifier, verifications[verifier].height - 1))

    #Caclulate the aggregate.
    var signatures: seq[BLSSignature]
    for index in indexes:
        signatures.add(
            verifications[verifier][verifications[verifier].archived .. index.nonce].calculateSig()
        )
    result.header.verifications = signatures.calculateSig()

    #Set the Header hash.
    result.hash = SHA512(result.header.serialize())

    #Set the Argon hash.
    result.argon = Argon(result.hash.toString(), proof.toBinary())
