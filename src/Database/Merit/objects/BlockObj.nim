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

finalsd:
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
        verifications*: Verifications
        #Who to attribute the Merit to (amount ranges from 0 to 100).
        miners* {.final.}: Miners

#Constructor.
proc newBlockObj*(
    nonce: uint,
    last: ArgonHash,
    verifications: Verifications,
    miners: Miners,
    time: uint,
    proof: uint
): Block {.raises: [ArgonError].} =
    #Create the Block.
    result = Block(
        header: newBlockheaderObj(
            nonce,
            last,
            verifications,
            miners,
            time
        ),
        proof: proof,
        verifications: verifications,
        miners: miners
    )

    #Set the Header hash.
    result.hash = SHA512(result.header.serialize())

    #Set the Argon hash.
    result.argon = Argon(result.hash.toString(), proof.toBinary())
