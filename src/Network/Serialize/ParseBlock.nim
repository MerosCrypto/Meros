#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Merkle lib.
import ../../lib/Merkle

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Lattice lib.
import ../../Database/Lattice/Lattice

#Miners and Block object.
import ../../Database/Merit/objects/MinersObj
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
        #Address 1 | Start Index 1 | End Index 1
        #Address N | Start Index N | End Index N
        #Merkle Tree | Publisher | Proof
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
        totalVerifications: int = 0
        #Verifications in the block.
        verifications: seq[
            tuple[
                validator: string,
                start: uint,
                last: uint
            ]
        ] = newSeq[
            tuple[
                validator: string,
                start: uint,
                last: uint
            ]
        ](blockSeq[3].toBN(256).toInt())
        #Hashes of the verifications.
        hashes: seq[SHA512Hash] = @[]
        #Merkle hash.
        merkle: string = blockSeq[4 + (verifications.len * 3)].toHex().pad(128)
        #Merkle Tree.
        tree: MerkleTree
        #Public Key of the Publisher.
        publisher: string = blockSeq[5 + (verifications.len * 3)].pad(32, char(0))
        #Proof.
        proof: string = blockSeq[6 + (verifications.len * 3)]
        #Miners length string.
        minersLenStr: string = blockSeq[blockSeq.len - 2]
        #Miners length.
        minersLen: int = minersLenStr.toBN(256).toInt()
        #Miners.
        miners: Miners
        #Signature.
        signature: string = blockSeq[blockSeq.len - 1].pad(64, char(0))

    #Make sure less than 100 miners were included.
    if blockSeq.len > (8 + (verifications.len * 3) + 200):
        raise newException(ValueError, "Parsed block had over 100 miners.")

    #Set the verifications.
    #Declare the loop variables outside to stop redeclarations.
    var
        firstVerification: int
        lastVerification: int
    for i in countup(4, 4 + (verifications.len * 3) - 1, 3):
        firstVerification = blockSeq[i + 1].toBN(256).toInt()
        lastVerification = blockSeq[i + 2].toBN(256).toInt()
        totalVerifications += lastVerification - firstVerification + 1

        verifications[int((i - 4) / 3)] = (
            validator: blockSeq[i].toHex(),
            start: uint(blockSeq[i + 1].toBN(256).toInt()),
            last: uint(blockSeq[i + 2].toBN(256).toInt())
        )

    #Grab the miners out of the block.
    var
        #End is the string end minus the signature length minus the length of the string that says the miners length.
        minersEnd: int = blockStr.len - 66 - (!minersLenStr).len
        minersStart: int = minersEnd - minersLen - 1
    var minersStr = !(newBN(nonce).toString(256)) & blockStr[minersStart .. minersEnd]
    #Parse the miners.
    miners = minersStr.parseMiners()

    #Create the MerkleTree object.
    var validator: string
    for i in 0 ..< verifications.len:
        validator = newAddress(verifications[i].validator.pad(32, char(0)))
        for v in verifications[i].start .. verifications[i].last:
            hashes.add(
                lattice[
                    newIndex(
                        validator,
                        newBN(v)
                    )
                ].hash
            )
    tree = newMerkleTree(hashes)

    #Create the Block Object.
    result = newBlockObj(last, nonce, time, verifications, tree, publisher.toHex())
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
