#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Lattice lib.
import ../../Database/Lattice/Lattice

#Miners, Verifications, and Block object.
import ../../Database/Merit/objects/MinersObj
import ../../Database/Merit/objects/VerificationsObj
import ../../Database/Merit/objects/BlockObj

#Serialize/parse functions.
import SerializeCommon
import SerializeMiners
import ParseMiners
import SerializeBlock

#Finals lib.
import finals

#String and seq utils standard libs.
import strutils
import sequtils

#Parse a Block.
proc parseBlock*(
    blockStr: string,
    lattice: Lattice
): Block {.raises: [
    ValueError,
    ArgonError,
    SodiumError,
    FinalAttributeError
].} =
    var
        #Nonce | Last | Time | Verifications Count
        #Sender 1 | Hash 1
        #Sender N | Hash N
        #BLS Signature | Publisher | Proof
        #Miner 1 | Amount 1
        #Miner N | Amount N
        #Miners Length
        #Signature
        blockSeq: seq[string] = blockStr.deserialize(13)
        #Nonce.
        nonce: int = blockSeq[0].toBN(256).toInt()
        #Last block hash.
        last: ArgonHash = blockSeq[1].pad(64, char(0)).toArgonHash()
        #Time.
        time: uint = uint(blockSeq[2].toBN(256).toInt())
        #Total Verifications.
        verificationCount: int = blockSeq[3].toBN(256).toInt()
        #Verifications in the block.
        verifications: Verifications = newVerificationsObj()
        #BLS signature of the Verifications.
        bls: string = blockSeq[4 + (verificationCount * 2)]
        #Public Key of the Publisher.
        publisher: string = blockSeq[5 + (verificationCount * 2)].pad(32, char(0))
        #Proof.
        proof: string = blockSeq[6 + (verificationCount * 2)]
        #Miners length string.
        minersLenStr: string = blockSeq[^2]
        #Miners length.
        minersLen: int = minersLenStr.toBN(256).toInt()
        #Miners.
        miners: Miners
        #Signature.
        signature: string = blockSeq[^1].pad(64, char(0))

    #Create the Verifications.
    for i in countup(4, 4 + (verificationCount * 2) - 1, 2):
        verifications.verifications.add(
            newVerificationObj(
                blockSeq[i + 1].toHash(512)
            )
        )
        verifications.verifications[^1].sender = newAddress(blockSeq[i])
    verifications.bls = bls

    #Grab the miners out of the block.
    var
        #End is the string end minus the signature length minus the length of the string that says the miners length.
        minersEnd: int = blockStr.len - 66 - (!minersLenStr).len
        minersStart: int = minersEnd - minersLen - 1
    var minersStr = !(newBN(nonce).toString(256)) & blockStr[minersStart .. minersEnd]
    #Parse the miners.
    miners = minersStr.parseMiners()

    #Create the Block Object.
    result = newBlockObj(last, nonce, time, verifications, publisher.toHex())
    #Set the hash.
    result.hash = SHA512(result.serialize())
    #Set the proof.
    result.proof = uint(proof.toBN(256).toInt())
    #Set the Argon hash.
    result.argon = Argon(result.hash.toString(), proof)
    #Set the miners.
    result.miners = miners
    #Set the miners hash.
    result.minersHash = SHA512(minersStr)

    #Verify the signature.
    if not newPublicKey(publisher).verify(result.minersHash.toString(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
