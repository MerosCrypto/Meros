#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Merkle lib.
import ../../../lib/Merkle

#Miners object.
import MinersObj

#Finals lib.
import finals

finalsd:
    #Define the Block class.
    type Block* = ref object of RootObj
        #Argon hash of the last block.
        last* {.final.}: ArgonHash
        #Nonce, AKA index.
        nonce* {.final.}: int
        #Timestamp.
        time*: uint
        #Validations.
        validations*: seq[tuple[validator: string, start: uint, last: uint]]
        #Merkle tree.
        merkle*: MerkleTree
        #Publisher address.
        publisher* {.final.}: string

        #Hash.
        hash*: SHA512Hash
        #Random hex number to make sure the Argon of the hash is over the difficulty.
        proof*: uint
        #Argon2d hash with the SHA512 hash as the data and proof as the salt.
        argon*: ArgonHash

        #Who to attribute the Merit to (amount ranges from 0 to 100).
        miners* {.final.}: Miners
        minersHash* {.final.}: SHA512Hash
        signature* {.final.}: string

#Constructor.
func newBlockObj*(
    last: ArgonHash,
    nonce: int,
    time: uint,
    validations: seq[tuple[validator: string, start: uint, last: uint]],
    merkle: MerkleTree,
    publisher: string
): Block {.raises: [].} =
    Block(
        last: last,
        nonce: nonce,
        time: time,
        validations: validations,
        merkle: merkle,
        publisher: publisher
    )

#Creates a new block without caring about the data.
proc newStartBlock*(genesis: string): Block {.raises: [ValueError, ArgonError].} =
    #Ceate the block.
    result = newBlockObj(
        Argon("", ""),
        0,
        getTime(),
        @[],
        newMerkleTree(@[]),
        "".pad(128, "0")
    )
    #Calculate the hash.
    result.hash = SHA512(genesis)
    #Set the proof.
    result.proof = 0
    #Calculate the Argon hash.
    result.argon = Argon(result.hash.toString(), $char(result.proof))
    #Set the miners.
    result.miners = @[]
    #Calculate the miners hash.
    result.minersHash = SHA512("")
    #Set the signature.
    result.signature = ""
