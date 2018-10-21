#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Miners and Verifications objects.
import MinersObj
import VerificationsObj

#Finals lib.
import finals

#String utils standard lib.
import strutils

finalsd:
    #Define the Block class.
    type Block* = ref object of RootObj
        #Argon hash of the last block.
        last* {.final.}: ArgonHash
        #Nonce, AKA index.
        nonce* {.final.}: uint
        #Timestamp.
        time*: uint

        #Verifications.
        verifications*: Verifications

        #Hash.
        hash*: SHA512Hash
        #Random hex number to make sure the Argon of the hash is over the difficulty.
        proof*: uint
        #Argon2d hash with the SHA512 hash as the data and proof as the salt.
        argon*: ArgonHash

        #Who to attribute the Merit to (amount ranges from 0 to 100).
        miners* {.final.}: Miners
        minersHash* {.final.}: SHA512Hash

        #Publisher.
        publisher* {.final.}: EdPublicKey
        #Signature of the Miners Hash.
        signature* {.final.}: string

#Constructor.
func newBlockObj*(
    last: ArgonHash,
    nonce: uint,
    time: uint,
    verifications: Verifications,
    publisher: EdPublicKey
): Block {.raises: [].} =
    Block(
        last: last,
        nonce: nonce,
        time: time,
        verifications: verifications,
        publisher: publisher
    )

#Creates a new block without caring about the data.
proc newStartBlock*(genesis: string): Block {.raises: [ValueError, ArgonError].} =
    #Ceate the block.
    var blankPublisher: array[32, cuchar]
    result = newBlockObj(
        Argon("", ""),
        0,
        getTime(),
        newVerificationsObj(),
        blankPublisher
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
