#Wallet Tests.

import WalletTests/MinerWalletTest

import WalletTests/Ed25519Test
import WalletTests/AddressTest
import WalletTests/WalletTest
import WalletTests/HDWalletTest
import WalletTests/MnemonicTest


proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(MinerWalletTest.test)

    tests.add(Ed25519Test.test)
    tests.add(AddressTest.test)
    tests.add(WalletTest.test)
    tests.add(HDWalletTest.test)
    tests.add(MnemonicTest.test)
