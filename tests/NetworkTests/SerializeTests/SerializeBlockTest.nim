#Serialize Block Tests.

#Numerical libs.
import BN
import ../../../src/lib/Base

#Time lib.
import ../../../src/lib/Time

#Hash lib.
import ../../../src/lib/Hash

#Merkle lib.
import ../../../src/lib/Merkle

#Wallet lib.
import ../../../src/Wallet/Wallet

#Merit libs.
import ../../../src/Database/Merit/Block

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
    nonce: BN = newBN(1)
    time: int
    proof: BN = newBN(1)
    miners: seq[tuple[miner: string, amount: int]] = @[(
        miner: wallet.address,
        amount: 100
    )]
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
        @[],
        newMerkleTree(@[]),
        $(wallet.publicKey),
        proof,
        miners,
        wallet.sign(SHA512(miners.serialize(nonce)).toString())
    )

    #Finally, update the last hash, increase the nonce, and reset the proof.
    last = newBlock.argon
    nonce = nonce + BNNums.ONE
    proof = newBN(i)

    #Serialize it and parse it back.
    var blockParsed: Block = newBlock.serialize().parseBlock(lattice)

    #Test the serialized versions.
    assert(newBlock.serialize() == blockParsed.serialize())

    #Test the Block properties.
    assert(newBlock.last == blockParsed.last)
    assert(newBlock.nonce == blockParsed.nonce)
    assert(newBlock.time == blockParsed.time)

    assert(newBlock.validations == blockParsed.validations)
    assert(newBlock.merkle.hash == blockParsed.merkle.hash)
    assert(newBlock.publisher == blockParsed.publisher)

    assert(newBlock.hash == blockParsed.hash)
    assert(newBlock.proof == blockParsed.proof)
    assert(newBlock.argon == blockParsed.argon)

    assert(newBlock.miners == blockParsed.miners)
    assert(newBlock.minersHash == blockParsed.minersHash)
    assert(newBlock.signature == blockParsed.signature)

echo "Finished the Network/Serialize/Block test."
