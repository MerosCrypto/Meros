#Address Test.

#Fuzzing lib.
import ../Fuzzed

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

suite "Address":
  noFuzzTest "Valid vectors.":
    check:
      "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7k7grplx".isValidAddress()
      "BC1SW50QA3JX3S".isValidAddress()
      "bc1zw508d6qejxtdg4y5r3zarvaryvg6kdaj".isValidAddress()

  noFuzzTest "Invalid vectors.":
    check:
      not "pzry9x0s0muk".isValidAddress()
      not "1pzry9x0s0muk".isValidAddress()
      not "bc1b4n0q5v".isValidAddress()

  noFuzzTest "Wallet address.":
    for _ in 0 ..< 100:
      var wallet: Wallet = newWallet("")
      check:
        wallet.address.isValidAddress()
        wallet.address.getEncodedData().addyType == AddressType.PublicKey
        wallet.publicKey.serialize() == cast[string](wallet.address.getEncodedData().data)
