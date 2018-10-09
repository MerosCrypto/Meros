#Serialize Block Tests.

#Util lib.
import ../../../src/lib/Util

#Numerical libs.
import BN
import ../../../src/lib/Base

#Hash lib.
import ../../../src/lib/Hash

#Wallet lib.
import ../../../src/Wallet/Wallet

#Merit lib.
import ../../../src/Database/Merit/Merit

#Lattice lib.
import ../../../src/Database/Lattice/Lattice

#Serialization libs.
import ../../../src/Network/Serialize/SerializeMiners
import ../../../src/Network/Serialize/SerializeBlock
import ../../../src/Network/Serialize/ParseBlock

var
    #Create a wallet to mine to.
    wallet: Wallet = newWallet()
    #Block var; defined here to stop a memory leak.
    newBlock: Block
    #Last block hash, nonce, time, and proof vars.
    last: ArgonHash = Argon(SHA512("mainnet").toString(), "00")
    nonce: int = 1
    time: uint
    proof: uint = 1
    miners: Miners = @[
        newMinerObj(
            wallet.address,
            100
        )
    ]
    lattice: Lattice = newLattice("", "")

import strutils, sequtils

#Mine Blocks.
for i in 1 .. 10:
    echo "Testing Block Serialization/Parsing, iteration " & $i & "."

    #Update the time.
    time = getTime()

    #Create a block.
    newBlock = newBlock(
        last,
        nonce,
        time,
        newVerificationsObj(),
        $(wallet.publicKey),
        proof,
        miners,
        wallet.sign(SHA512(miners.serialize(nonce)).toString())
    )
    newBlock.verifications.bls = ""

    #Finally, update the last hash, increase the nonce, and reset the proof.
    last = newBlock.argon
    nonce = nonce + 1
    proof = uint(i)

    #Serialize it and parse it back.
    var blockParsed: Block = newBlock.serialize().parseBlock(lattice)

    #Test the serialized versions.
    assert(newBlock.serialize() == blockParsed.serialize())

    #Test the Block properties.
    assert(newBlock.last == blockParsed.last)
    assert(newBlock.nonce == blockParsed.nonce)
    assert(newBlock.time == blockParsed.time)

    assert(newBlock.verifications.verifications.len == blockParsed.verifications.verifications.len)
    for i in 0 ..< newBlock.verifications.verifications.len:
        assert(newBlock.verifications.verifications[i].sender == blockParsed.verifications.verifications[i].sender)
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
