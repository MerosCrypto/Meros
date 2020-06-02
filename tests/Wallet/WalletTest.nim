#Wallet Test.

#Fuzzing lib.
import ../Fuzzed

#Util lib.
import ../../src/lib/Util

#Wallet libs.
import ../../src/Wallet/Address
import ../../src/Wallet/Wallet

#Random standard lib.
import random

proc verify(
  wallet: Wallet
) =
  #Test recreating the Public Key.
  check(newEdPublicKey(wallet.publicKey.toString()).toString() ==
    wallet.publicKey.toString())
  check($newEdPublicKey($wallet.publicKey) == $wallet.publicKey)

  #Create messages.
  var
    msg: string
    sig: EdSignature
  for m in 1 .. rand(100):
    msg = ""
    for _ in 0 ..< m:
      msg &= char(rand(255))

    #Sign the message.
    sig = wallet.sign(msg)

    #Verify the signature.
    check(wallet.verify(msg, sig))

suite "Wallet":
  noFuzzTest "New Wallet without password.":
    verify(newWallet(""))

  noFuzzTest "New Wallet with password.":
    verify(newWallet("password"))

  noFuzzTest "Reloaded Wallet.":
    var
      wallet = newWallet("password")
      reloaded = newWallet(wallet.mnemonic.sentence, "password")

    check(wallet.mnemonic.entropy == reloaded.mnemonic.entropy)
    check(wallet.mnemonic.checksum == reloaded.mnemonic.checksum)
    check(wallet.mnemonic.sentence == reloaded.mnemonic.sentence)

    check(wallet.hd.chainCode == reloaded.hd.chainCode)
    check(wallet.hd.privateKey == reloaded.hd.privateKey)
    check(wallet.hd.publicKey == reloaded.hd.publicKey)
    check(wallet.hd.address == reloaded.hd.address)
