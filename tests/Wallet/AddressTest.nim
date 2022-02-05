#Address Test.

#Fuzzing lib.
import ../Fuzzed

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

suite "Address":
  noFuzzTest "Valid vectors.":
    check:
      "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kt5nd6y".isValidAddress()
      "BC1SW50QGDZ25J".isValidAddress()
      "bc1zw508d6qejxtdg4y5r3zarvaryvaxxpcs".isValidAddress()
      "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0".isValidAddress()

  noFuzzTest "Invalid vectors.":
    check:
      not "tc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq5zuyut".isValidAddress()
      not "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqh2y7hd".isValidAddress()
      not "BC1S0XLXVLHEMJA6C4DQV22UAPCTQUPFHLXM9H8Z3K2E72Q4K9HCZ7VQ54WELL".isValidAddress()
      not "bc1p38j9r5y49hruaue7wxjce0updqjuyyx0kh56v8s25huc6995vvpql3jow4".isValidAddress()
      not "bc1Zw508d6qejxtdg4y5r3zarvaryvaxxpcs".isValidAddress()
      not "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7v07qwwzcrf".isValidAddress()
      not "bc1gmk9yu".isValidAddress()

  noFuzzTest "Wallet address.":
    for _ in 0 ..< 100:
      var wallet: HDWallet = newWallet("").hd
      check:
        wallet.address.isValidAddress()
        wallet.address.getEncodedData().addyType == AddressType.PublicKey
        wallet.publicKey.serialize() == cast[string](wallet.address.getEncodedData().data)
