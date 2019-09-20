#Address Test.

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

proc test*() =
    #Test vectors.
    assert("bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7k7grplx".isValidAddress())
    assert("BC1SW50QA3JX3S".isValidAddress())
    assert("bc1zw508d6qejxtdg4y5r3zarvaryvg6kdaj".isValidAddress())

    #Invalid vectors.
    assert(not "pzry9x0s0muk".isValidAddress())
    assert(not "1pzry9x0s0muk".isValidAddress())
    assert(not "bc1b4n0q5v".isValidAddress())

    #Run 100 times.
    for i in 1 .. 100:
        #Wallet.
        var wallet: Wallet = newWallet("")

        #Verify the address.
        assert(wallet.address.isValidAddress())

        #Verify it decodes properly.
        assert(wallet.publicKey.toString() == cast[string](wallet.address.getEncodedData()))

    echo "Finished the Wallet/Address Test."
