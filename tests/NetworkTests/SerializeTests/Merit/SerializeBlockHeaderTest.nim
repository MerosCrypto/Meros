#Serialize Block Header Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS/MinerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Wallet/MinerWallet

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#BlockHeader object.
import ../../../../src/Database/Merit/objects/BlockHeaderObj

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeBlockHeader
import ../../../../src/Network/Serialize/Merit/ParseBlockHeader

#Random standard lib.
import random

#Set the seed to be based on the time.
randomize(int(getTime()))

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing BlockHeader Serialization/Parsing, iteration " & $i & "."

    var
        #Header.
        header: BlockHeader = BlockHeader()
        #Nonce.
        nonce: uint = uint(rand(65000))
        #Last Block's Hash.
        last: ArgonHash
        #Miner Wallet.
        miner: MinerWallet = newMinerWallet()
        #Verifications.
        verifs: BLSSignature
        #Miners Hash.
        miners: Blake512Hash
        #Time.
        time: uint = getTime()
        #Proof.
        proof: uint = uint(rand(500000))

    #Randomze the hashes.
    for b in 0 ..< 64:
        last.data[b] = uint8(rand(255))
        miners.data[b] = uint8(rand(255))

    #Create a Random BLS signature.
    verifs = miner.sign(last.toString())

    #Create the Header.
    header.nonce = uint(nonce)
    header.last = last
    header.verifications = verifs
    header.miners = miners
    header.time = time
    header.proof = proof

    #Serialize it and parse it back.
    var headerParsed: BlockHeader = header.serialize().parseBlockHeader()

    #Test the serialized versions.
    assert(header.serialize() == headerParsed.serialize())

    #Test each field.
    assert(header.nonce == headerParsed.nonce)
    assert(header.last == headerParsed.last)
    assert(header.verifications == headerParsed.verifications)
    assert(header.miners == headerParsed.miners)
    assert(header.time == headerParsed.time)
    assert(header.proof == headerParsed.proof)

echo "Finished the Network/Serialize/Merit/BlockHeader test."
