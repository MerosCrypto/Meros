#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Lattice lib.
import ../../../Database/Lattice/Lattice

#Verifications, Miners, and Block object.
import ../../../Database/Merit/objects/VerificationsObj
import ../../../Database/Merit/objects/MinersObj
import ../../../Database/Merit/objects/BlockObj

#Deserialize/parse functions.
import ../SerializeCommon
import ParseBlockHeader
import ParseVerifications
import ParseMiners

#Finals lib.
import finals

#Parse a Block.
proc parseBlock*(
    blockStr: string
): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    FinalAttributeError
].} =
    #Header | Proof | Verifications Count | Miners
    var blockSeq: seq[string] = blockStr.deserialize(4)

    #Create the Block Object.
    result = Block()

    #Set the Header.
    result.header = blockSeq[0].parseBlockHeader()
    #Set the proof.
    result.proof = uint(blockSeq[1].fromBinary())

    #Set the hash.
    result.hash = SHA512(blockSeq[0])
    #Set the Argon hash.
    result.argon = Argon(result.hash.toString(), result.proof.toBinary())

    #Set the Verifications.
    result.verifications = blockSeq[2].parseVerifications(result.header.verifications)

    #Set the Miners.
    result.miners = blockSeq[3].parseMiners()
