#Serialize Miners Tests.

#Numerical libs.
import BN
import ../../../src/lib/Base

#Wallet and Address libs.
import ../../../src/Wallet/Wallet

#Serialize lib.
import ../../../src/Network/Serialize/SerializeMiners
import ../../../src/Network/Serialize/ParseMiners

#SetOnce lib.
import SetOnce

#Random/Time/Algorithm standard libs. They're used to randomize the testing data.
import random
import times
import algorithm

#Set the seed to be based on the time.
randomize(getTime().toUnix())

#Test 20 serializations.
for i in 1 .. 10:
    var
        #Wallets.
        wallets: seq[Wallet] = @[]
        #Miners.
        miners: seq[
            tuple[
                miner: string,
                amount: int
            ]
        ] = @[]
        #Quantity.
        quantity: int = (rand(99) + 1) #Returns to 1 to 100.
        #Amount temp variable.
        amount: int
        #Remaining amount.
        remaining: int = 100

    #Test the lowest quantity.
    if i == 1:
        quantity = 1
    #Test the highest quantity.
    elif i == 10:
        quantity = 100

    echo "Testing Miners Serialization/Parsing, iteration " & $i & ", with " & $quantity & " miners."

    for i in 0 ..< quantity:
        #Generate a Wallet for them.
        wallets.add(newWallet())
        #Add the tuple/set their public key.
        miners.add((miner: wallets[i].address.toValue(), amount: 0))

        #Set the amount to pay the miner.
        amount = rand(remaining - 1) + 1
        #Make sure everyone gets at least 1 and we don't go over 1000.
        if (remaining - amount) < (quantity - i):
            amount = 1
            #But if this is the last account...
            if i == quantity - 1:
                amount = remaining

        #Set the miner's amount.
        miners[i].amount = amount
        #Subtract the amount from remaining.
        remaining -= amount

    #Randomly order the miners.
    miners.sort(
        proc (x: tuple[miner: string, amount: int], y: tuple[miner: string, amount: int]): int =
            rand(1000)
    )

    #Serialize it and parse it back.
    var minersParsed: seq[
        tuple[
            miner: string,
            amount: int
        ]
    ] = miners.serialize(newBN()).parseMiners()

    #Test the serialized versions.
    assert(miners.serialize(newBN()) == minersParsed.serialize(newBN()))

    #Test the for equality.
    assert(miners == minersParsed)

echo "Finished the Network/Serialize/Miners test."
