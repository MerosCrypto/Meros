#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Hashing libs.
import ../../lib/SHA512
import ../../lib/Argon

#Block and MerkleTree objects.
import ../../Database/Merit/objects/BlockObj
import ../../Database/Merit/Merkle

#delim character/serialize/parse functions.
import common
import SerializeMiners
import ParseMiners
import SerializeBlock

#String and seq utils standard libs.
import strutils
import sequtils

#Parse a block.
proc parseBlock*(blockStr: string): Block {.raises: [Exception].} =
    var
        #Nonce | Last | Time | Validations Count
        #Address 1 | Start Index 1 | End Index 1
        #Address N | Start Index N | End Index N
        #Merkle Tree | Publisher | Proof
        #Miner 1 | Amount 1
        #Miner N | Amount N
        #Signature
        blockSeq: seq[string] = blockStr.split(delim)
        #Nonce.
        nonce: BN = blockSeq[0].toBN(255)
        #Last block hash.
        last: string = blockSeq[1].toBN(255).toString(16).pad(128)
        #Time.
        time: BN = blockSeq[2].toBN(255)
        #Validations in the block.
        validations: seq[
            tuple[
                validator: string,
                start: int,
                last: int
            ]
        ] = newSeq[
            tuple[
                validator: string,
                start: int,
                last: int
            ]
        ](blockSeq[3].toBN(255).toInt())
        #Merkle hash.
        merkle: string = blockSeq[4 + (validations.len * 3)].toBN(255).toString(16).pad(128)
        #Merkle Tree.
        tree: MerkleTree
        #Public Key of the Publisher.
        publisher: string = blockSeq[5 + (validations.len * 3)].toBN(255).toString(16).pad(64)
        #Proof.
        proof: BN = blockSeq[6 + (validations.len * 3)].toBN(255)
        #seq from blockSeq that's just the miners.
        minersSeq: seq[string] = blockSeq
        #Serialized miners.
        minersSerialized: string
        #Miners.
        miners: seq[
            tuple[
                miner: string,
                amount: int
            ]
        ] = newSeq[
            tuple[
                miner: string,
                amount: int
            ]
        ]()
        #Signature.
        signature: string = blockSeq[blockSeq.len - 1].toBN(255).toString(16).pad(64)

    #Set the validations.
    for i in countup(4, 4 + (validations.len * 3) - 1, 3):
        validations[int((i - 4) / 3)] = (
            validator: blockSeq[i].toBN(255).toString(16).pad(64),
            start: blockSeq[i + 1].toBN(255).toInt(),
            last: blockSeq[i + 2].toBN(255).toInt()
        )

    #Filter the blockSeq to just the miners.
    #Set the first element to the nonce.
    minersSeq[0] = nonce.toString(255)
    #Delete all other data.
    minersSeq.delete(1, 4 + (validations.len * 3) - 1)
    minersSeq.delete(minersSeq.len - 1)
    minersSerialized = minersSeq.join(delim)
    miners = parseMiners(minersSerialized)

    #Create the MerkleTree object.

    #Create the Block Object.
    result = newBlockObj(last, nonce, time, validations, tree, publisher, proof, miners, signature)
    #Set the hash.
    result.setHash(SHA512(result.serialize()))
    #Set the Argon hash.
    result.setArgon(Argon(result.getHash(), result.getProof().toString(16)))
    #Set the miners hash.
    result.setMinersHash(SHA512(minersSerialized))
