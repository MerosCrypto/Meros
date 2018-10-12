#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Serialization lib.
import ../../Network/Serialize/SerializeMiners
import ../../Network/Serialize/SerializeBlock

#Miners and Verifications objects.
import objects/MinersObj
import objects/VerificationsObj

#Block object.
import objects/BlockObj
#Export the Block object.
export BlockObj

#Finals lib.
import finals

#String utils standard library.
import strutils

#New Block function. Creates a new block. Raises an error if there's an issue.
proc newBlock*(
    last: ArgonHash,
    nonce: uint,
    time: uint,
    verifications: Verifications,
    publisher: string,
    proof: uint,
    miners: Miners,
    signature: string
): Block {.raises: [
    ValueError,
    ArgonError,
    SodiumError,
    FinalAttributeError
].} =
    #Verify the arguments.
    #Verifications.
    for verification in verifications.verifications:
        if not Address.verify(verification.sender):
            raise newException(ValueError, "Invalid verification address.")

    #Miners.
    var total: uint = 0
    if (miners.len < 1) or (100 < miners.len):
        raise newException(ValueError, "Invalid miners quantity.")
    for miner in miners:
        total += miner.amount
        if not Address.verify(miner.miner):
            raise newException(ValueError, "Invalid miner address.")
        if (miner.amount < 1) or (uint(100) < miner.amount):
            raise newException(ValueError, "Invalid miner amount.")
    if total != 100:
        raise newException(ValueError, "Invalid total miner amount.")

    #Ceate the block.
    result = newBlockObj(
        last,
        nonce,
        time,
        verifications,
        publisher
    )

    #Calculate the hash.
    result.hash = SHA512(result.serialize())
    #Set the proof.
    result.proof = proof
    #Calculate the Argon hash.
    result.argon = Argon(result.hash.toString(), result.proof.toBinary())

    #Set the miners.
    result.miners = miners
    #Calculate the miners hash.
    result.minersHash = SHA512(miners.serialize(nonce))
    #Verify the signature.
    if not newPublicKey(publisher).verify(result.minersHash.toString(), signature):
        raise newException(ValueError, "Invalid miners' signature.")
    #Set the signature.
    result.signature = signature
