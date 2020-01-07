#Address Test.

#Test lib.
import unittest2

#Fuzzing lib.
import ../Fuzzed

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

suite "Address":
    test "Valid vectors.":
        check("bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7k7grplx".isValidAddress())
        check("BC1SW50QA3JX3S".isValidAddress())
        check("bc1zw508d6qejxtdg4y5r3zarvaryvg6kdaj".isValidAddress())

    test "Invalid vectors.":
        check(not "pzry9x0s0muk".isValidAddress())
        check(not "1pzry9x0s0muk".isValidAddress())
        check(not "bc1b4n0q5v".isValidAddress())

    lowFuzzTest "Wallet address.":
        #Wallet.
        var wallet: Wallet = newWallet("")

        #Verify the address.
        check(wallet.address.isValidAddress())

        #Verify it decodes properly.
        check(wallet.publicKey.toString() == cast[string](wallet.address.getEncodedData()))
