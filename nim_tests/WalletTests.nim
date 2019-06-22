#Wallet Tests.

import WalletTests/Ed25519Test
import WalletTests/BLSTest

import WalletTests/AddressTest
import WalletTests/WalletTest
import WalletTests/HDWalletTest

import WalletTests/MinerWalletTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(Ed25519Test.test)
    tests.add(BLSTest.test)
    tests.add(AddressTest.test)
    tests.add(WalletTest.test)
    tests.add(HDWalletTest.test)
    tests.add(MinerWalletTest.test)
