#Numerical libraries.
import ../../../lib/BN
import ../../../lib/Base

#Time library.
import ../../../lib/Time

#SHA512 library.
import ../../../lib/SHA512

#Argon library.
import ../../../lib/Argon

#Import the Merkle library.
import ../Merkle

#Define the Block class.
type Block* = ref object of RootObj
    #Argon hash of the last block.
    last: string
    #Nonce, AKA index.
    nonce: BN
    #Timestamp.
    time: BN
    #Validations.
    validations: seq[tuple[validator: string, start: int, last: int]]
    #Merkle tree.
    merkle: MerkleTree
    #Publisher address.
    publisher: string

    #Hash.
    hash: string
    #Random hex number to make sure the Argon of the hash is over the difficulty.
    proof: BN
    #Argon2d 64 character hash with the hash as the data and proof as the salt.
    argon: string

    #Who to attribute the Merit to (amount ranges from 0 to 1000).
    miners: seq[tuple[miner: string, amount: int]]
    minersHash: string
    signature: string

#Constructor.
proc newBlockObj*(
    last: string,
    nonce: BN,
    time: BN,
    validations: seq[tuple[validator: string, start: int, last: int]],
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
proc newStartBlock*(genesis: string): Block {.raises: [ValueError, AssertionError].} =
    #Ceate the block.
    result = newBlockObj(
        "",
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
    result.argon = Argon(result.hash, result.proof.toString(16))
    #Set the miners.
    result.miners = @[]
    #Calculate the miners hash.
    result.minersHash = SHA512("00")
    #Set the signature.
    result.signature = ""

#Setters.
proc setHash*(blockArg: Block, hash: string): bool {.raises: [].} =
    result = true
    if not blockArg.hash.isNil:
        return false

    blockArg.hash = hash

proc setProof*(newBlock: Block, proof: BN): bool {.raises: [].} =
    result = true
    if not newBlock.proof.isNil:
        return false

    newBlock.proof = proof

proc setArgon*(blockArg: Block, argon: string): bool {.raises: [].} =
    result = true
    if not blockArg.argon.isNil:
        return false

    blockArg.argon = argon

proc setMiners*(newBlock: Block, miners: seq[tuple[miner: string, amount: int]]): bool {.raises: [].} =
    result = true
    if not newBlock.miners.isNil:
        return false

    newBlock.miners = miners

proc setMinersHash*(blockArg: Block, minersHash: string): bool {.raises: [].} =
    result = true
    if not blockArg.minersHash.isNil:
        return false

    blockArg.minersHash = minersHash

proc setSignature*(newBlock: Block, signature: string): bool {.raises: [].} =
    result = true
    if not newBlock.signature.isNil:
        return false

    newBlock.signature = signature

#Getters.
proc getLast*(blockArg: Block): string {.raises: [].} =
    blockArg.last
proc getNonce*(blockArg: Block): BN {.raises: [].} =
    blockArg.nonce
proc getTime*(blockArg: Block): BN {.raises: [].} =
    blockArg.time
proc getValidations*(blockArg: Block): seq[tuple[validator: string, start: int, last: int]] {.raises: [].} =
    blockArg.validations
proc getMerkle*(blockArg: Block): MerkleTree {.raises: [].} =
    blockArg.merkle
proc getPublisher*(blockArg: Block): string {.raises: [].} =
    blockArg.publisher
proc getHash*(blockArg: Block): string {.raises: [].} =
    blockArg.hash
proc getProof*(blockArg: Block): BN {.raises: [].} =
    blockArg.proof
proc getArgon*(blockArg: Block): string {.raises: [].} =
    blockArg.argon
proc getMiners*(blockArg: Block): seq[tuple[miner: string, amount: int]] {.raises: [].} =
    blockArg.miners
proc getMinersHash*(blockArg: Block): string {.raises: [].} =
    blockArg.minersHash
proc getSignature*(blockArg: Block): string {.raises: [].} =
    blockArg.signature
