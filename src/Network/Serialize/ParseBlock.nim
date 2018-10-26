#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

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

#BLS lib.
import ../../lib/BLS

#Parse a Block.
proc parseBlock*(
    blockStr: string
): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError,
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
        nonce: uint = uint(blockSeq[0].fromBinary())
        #Last block hash.
        last: ArgonHash = blockSeq[1].pad(64).toArgonHash()
        #Time.
        time: uint = uint(blockSeq[2].fromBinary())
        #Total Verifications.
        verificationCount: int = blockSeq[3].fromBinary()
        #Verifications in the block.
        verifications: Verifications = newVerificationsObj()
        #Aggregate signature of the Verifications.
        aggregate: string = blockSeq[4 + (verificationCount * 2)].pad(96)
        #Public Key of the Publisher.
        publisher: string = blockSeq[5 + (verificationCount * 2)].pad(32)
        #Proof.
        proof: string = blockSeq[6 + (verificationCount * 2)]
        #Miners length string.
        minersLenStr: string = blockSeq[^2]
        #Miners length.
        minersLen: int = minersLenStr.fromBinary()
        #Miners.
        miners: Miners
        #Signature.
        signature: string = blockSeq[^1].pad(64)

    #Create the Verifications.
    for i in countup(4, 4 + (verificationCount * 2) - 1, 2):
        verifications.verifications.add(
            newMemoryVerificationObj(
                blockSeq[i + 1].toHash(512)
            )
        )
        try:
            verifications.verifications[^1].verifier = newBLSPublicKey(blockSeq[i])
        except:
            raise newException(BLSError, "Couldn't load the BLS Public Key.")
    try:
        verifications.aggregate = newBLSSignature(aggregate)
    except:
        raise newException(BLSError, "Couldn't load the BLS Signature.")

    #Grab the miners out of the block.
    var
        #End is the string end minus the signature length minus the length of the string that says the miners length.
        minersEnd: int = blockStr.len - 66 - (!minersLenStr).len
        minersStart: int = minersEnd - minersLen - 1
    var minersStr = !nonce.toBinary() & blockStr[minersStart .. minersEnd]
    #Parse the miners.
    miners = minersStr.parseMiners()

    #Create the Block Object.
    result = newBlockObj(last, nonce, time, verifications, newEdPublicKey(publisher))
    #Set the hash.
    result.hash = SHA512(result.serialize())
    #Set the proof.
    result.proof = uint(proof.fromBinary())
    #Set the Argon hash.
    result.argon = Argon(result.hash.toString(), proof)
    #Set the miners.
    result.miners = miners
    #Set the miners hash.
    result.minersHash = SHA512(minersStr)

    #Verify the signature.
    if not newEdPublicKey(publisher).verify(result.minersHash.toString(), signature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = signature
