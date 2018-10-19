#Serialize Block Tests.

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#Wallet lib.
import ../../../src/Wallet/Wallet

#Merit lib.
import ../../../src/Database/Merit/Merit

#Serialization libs.
import ../../../src/Network/Serialize/SerializeMiners
import ../../../src/Network/Serialize/SerializeBlock
import ../../../src/Network/Serialize/ParseBlock

#BLS lib.
import BLS

#Random lib.
import random

import strutils

var
    #Create a wallet to mine to.
    wallet: Wallet = newWallet()
    #Block var; defined here to stop a memory leak.
    newBlock: Block
    #Last block hash, nonce, time, and proof vars.
    last: ArgonHash = Argon(SHA512("mainnet").toString(), "00")
    nonce: uint = 1
    time: uint
    proof: uint = 1
    #Miner's Wallet.
    miner: MinerWallet
    #Miners object.
    miners: Miners
    #Hash for the Verification.
    hash: Hash[512]
    #Verification.
    verif: Verification
    #Verifications.
    verifs: Verifications

#Mine Blocks.
for i in 1 .. 10:
    echo "Testing Block Serialization/Parsing, iteration " & $i & "."

    #Update the time.
    time = getTime()

    #Create a new MinerWallet.
    miner = newMinerWallet()

    #Create the Miners object.
    miners = @[
       newMinerObj(
           miner.publicKey,
           100
       )
    ]

    #Set the hash to a random vaue.
    for i in 0 ..< 64:
        hash.data[i] = uint8(rand(255))
    #Create a Verification.
    var verif: MemoryVerification = newMemoryVerification(hash)
    miner.sign(verif)

    #Create a new Verifications object.
    verifs = newVerificationsObj()
    #Add the Verification.
    verifs.verifications.add(verif)

    #Calculate the Verifications sig.
    verifs.calculateSig()

    #Create a block.
    newBlock = newBlock(
        last,
        nonce,
        time,
        verifs,
        wallet.publicKey,
        proof,
        miners,
        wallet.sign(SHA512(miners.serialize(nonce)).toString())
    )

    #Finally, update the last hash, increase the nonce, and reset the proof.
    last = newBlock.argon
    nonce = nonce + 1
    proof = uint(i)

    #Serialize it and parse it back.
    var blockParsed: Block = newBlock.serialize().parseBlock()

    #Test the serialized versions.
    assert(newBlock.serialize() == blockParsed.serialize())

    #Test the Block properties.
    assert(newBlock.last == blockParsed.last)
    assert(newBlock.nonce == blockParsed.nonce)
    assert(newBlock.time == blockParsed.time)

    assert(newBlock.verifications.verifications.len == blockParsed.verifications.verifications.len)
    for i in 0 ..< newBlock.verifications.verifications.len:
        assert(newBlock.verifications.verifications[i].verifier == blockParsed.verifications.verifications[i].verifier)
        assert(newBlock.verifications.verifications[i].hash == blockParsed.verifications.verifications[i].hash)
    assert(newBlock.publisher == blockParsed.publisher)

    assert(newBlock.hash == blockParsed.hash)
    assert(newBlock.proof == blockParsed.proof)
    assert(newBlock.argon == blockParsed.argon)

    assert(newBlock.miners.len == blockParsed.miners.len)
    for i in 0 ..< newBlock.miners.len:
        assert(newBlock.miners[i].miner == blockParsed.miners[i].miner)
        assert(newBlock.miners[i].amount == blockParsed.miners[i].amount)

    assert(newBlock.minersHash == blockParsed.minersHash)
    assert(newBlock.signature == blockParsed.signature)

echo "Finished the Network/Serialize/Block test."
