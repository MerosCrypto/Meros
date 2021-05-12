import ../../src/Wallet/Wallet

import ../Fuzzed

suite "HDWallet":
  highFuzzTest "Public key derivation":
    var wallet: HDWallet = newWallet("").hd[0]
    check HDPublic(
      key: wallet.derive(0).publicKey,
      chainCode: wallet.derive(0).chainCode,
      index: 0
    ) == HDPublic(
      key: wallet.publicKey,
      chainCode: wallet.chainCode
    ).derivePublic(0)
