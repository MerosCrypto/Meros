#Serialize Verifications Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS/MinerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Wallet/MinerWallet

#Index object.
import ../../../../src/Database/common/objects/IndexObj

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#Serialize libs.
import ../../../../src/Network/Serialize/Verifications/SerializeVerifications
import ../../../../src/Network/Serialize/Verifications/ParseVerifications

#Random standard lib.
import random

#Algorithm standard lib; used to randomize the Verifications/Miners order.
import algorithm

#Set the seed to be based on the time.
randomize(int(getTime()))

for i in 1 .. 20:
    echo "Testing Verifications Serialization/Parsing, iteration " & $i & "."

    var
        #Verifications.
        verifs: Verifications = newVerifications()
        #Verifiers.
        verifiers: seq[MinerWallet] = @[]
        #Verifier quantity.
        verifierQuantity: int = rand(99) + 1
        #Indexes.
        indexes: seq[Index] = @[]
        #Amount of Verifications to create for the Verifier.
        amount: int

    #Fill up the Verifiers.
    for v in 0 ..< verifierQuantity:
        verifiers.add(newMinerWallet())

    #Create Verifications.
    for verifier in verifiers:
        #Amount of Verifications.
        amount = rand(99) + 1
        #Add it to indexes.
        indexes.add(newIndex(verifier.publicKey.toString(), uint(amount - 1)))

        #Create the Verifications.
        for a in 0 ..< amount:
            var
                #Random hash to verify.
                hash: Hash[512]
                #Verification.
                verif: MemoryVerification

            #Randomize the hash.
            for b in 0 ..< 64:
                hash.data[b] = uint8(rand(255))

            #Create the Verification.
            verif = newMemoryVerificationObj(hash)
            verifier.sign(verif, uint(a))
            verifs.add(verif)

    #Serialize it and parse it back.
    var indexesParsed: seq[Index] = indexes.serialize(verifs).parseVerifications(verifs)

    #Test the serialized versions.
    assert(indexes.serialize(verifs) == indexesParsed.serialize(verifs))

    #Test the Verifications.
    for v in 0 ..< indexes.len:
        assert(indexes[v].key == indexesParsed[v].key)
        assert(indexes[v].nonce == indexesParsed[v].nonce)

echo "Finished the Network/Serialize/Merit/Block test."
