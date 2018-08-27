#Number libs.
import ../../../src/lib/BN
import ../../../src/lib/Base

#Time lib.
import ../../../src/lib/Time

#Hashing libs.
import ../../../src/lib/SHA512
import ../../../src/lib/Argon

#Wallet lib.
import ../../../src/Wallet/Wallet

#Merit libs.
import ../../../src/Database/Merit/Merkle
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
    #Get the address.
    miner: string = wallet.getAddress()
    #Get the publisher.
    publisher: string = $wallet.getPublicKey()
    #Block var; defined here to stop a memory leak.
    newBlock: Block
    #Last block hash, nonce, time, and proof vars.
    last: string = Argon(SHA512("mainnet"), "00")
    nonce: BN = newBN(1)
    time: BN
    proof: BN = newBN(1)
    miners: seq[tuple[miner: string, amount: int]] = @[(
        miner: miner,
        amount: 100
    )]
    lattice: Lattice = newLattice()

import strutils, sequtils

#Mine Blocks.
for i in 1 .. 10:
    echo "Testing Block Serialization/Parsing, iteration " & $i & "."

    #Update the time.
    time = newBN(getTime())

    #Create a block.
    newBlock = newBlock(
        last,
        nonce,
        time,
        @[],
        newMerkleTree(@[]),
        publisher,
        proof,
        miners,
        wallet.sign(SHA512(miners.serialize(nonce)))
    )

    #Finally, update the last hash, increase the nonce, and reset the proof.
    last = newBlock.getArgon()
    nonce = nonce + BNNums.ONE
    proof = newBN(i)

    #Serialize it and parse it back.
    var blockParsed: Block = newBlock.serialize().parseBlock(lattice)

    #Test the serialized versions.
    assert(newBlock.serialize() == blockParsed.serialize())

    #Test the Block properties.
    assert(newBlock.getLast() == blockParsed.getLast())
    assert(newBlock.getNonce() == blockParsed.getNonce())
    assert(newBlock.getTime() == blockParsed.getTime())

    assert(newBlock.getValidations() == blockParsed.getValidations())
    assert(newBlock.getMerkle().getHash() == blockParsed.getMerkle().getHash())
    assert(newBlock.getPublisher() == blockParsed.getPublisher())

    assert(newBlock.getProof() == blockParsed.getProof())
    assert(newBlock.getHash() == blockParsed.getHash())
    assert(newBlock.getArgon() == blockParsed.getArgon())

    assert(newBlock.getMiners() == blockParsed.getMiners())
    assert(newBlock.getMinersHash() == blockParsed.getMinersHash())
    assert(newBlock.getSignature() == blockParsed.getSignature())

echo "Finished the Network/Serialize/Block test."
