#Numerical libraries.
import BN as BNFile
import ../../../lib/Base

#Time lib.
import ../../../lib/Time

#Hash lib.
import ../../../lib/Hash

#Merkle lib.
import ../../../lib/Merkle

#Finals lib.
import finals

finalsd:
    #Define the Block class.
    type Block* = ref object of RootObj
        #Argon hash of the last block.
        last* {.final.}: ArgonHash
        #Nonce, AKA index.
        nonce* {.final.}: BN
        #Timestamp.
        time*: BN
        #Validations.
        validations*: seq[tuple[validator: string, start: int, last: int]]
        #Merkle tree.
        merkle*: MerkleTree
        #Publisher address.
        publisher* {.final.}: string

        #Hash.
        hash*: SHA512Hash
        #Random hex number to make sure the Argon of the hash is over the difficulty.
        proof*: BN
        #Argon2d hash with the SHA512 hash as the data and proof as the salt.
        argon*: ArgonHash

        #Who to attribute the Merit to (amount ranges from 0 to 1000).
        miners* {.final.}: seq[tuple[miner: string, amount: int]]
        minersHash* {.final.}: SHA512Hash
        signature* {.final.}: string

#Constructor.
proc newBlockObj*(
    last: ArgonHash,
    nonce: BN,
    time: BN,
    validations: seq[tuple[validator: string, start: int, last: int]],
    merkle: MerkleTree,
    publisher: string
): Block {.raises: [].} =
    result = Block(
        last: last,
        nonce: nonce,
        time: time,
        validations: validations,
        merkle: merkle,
        publisher: publisher
    )

#Creates a new block without caring about the data.
proc newStartBlock*(genesis: string): Block {.raises: [ValueError].} =
    #Ceate the block.
    result = newBlockObj(
        Argon("", ""),
        newBN(),
        getTime(),
        @[],
        newMerkleTree(@[]),
        ""
    )
    #Calculate the hash.
    result.hash = SHA512(genesis)
    #Set the proof.
    result.proof = newBN()
    #Calculate the Argon hash.
    result.argon = Argon(result.hash.toString(), result.proof.toString(256))
    #Set the miners.
    result.miners = @[]
    #Calculate the miners hash.
    result.minersHash = SHA512("")
    #Set the signature.
    result.signature = ""
