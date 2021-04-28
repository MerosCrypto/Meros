import random

import ../../src/lib/Util

import ../../src/Wallet/[Address, Wallet]

import ../Fuzzed

proc verify(
  insecure: InsecureWallet
) =
  let wallet: HDWallet = insecure.hd

  #Test recreating the Public Key.
  check:
    newEdPublicKey(wallet.publicKey.serialize()).serialize() == wallet.publicKey.serialize()
    $newEdPublicKey(parseHexStr($wallet.publicKey)) == $wallet.publicKey

  #Create messages.
  var
    msg: string
    sig: EdSignature
  for m in 1 .. rand(100):
    msg = ""
    for _ in 0 ..< m:
      msg &= char(rand(255))
    sig = wallet.sign(msg)
    check wallet.verify(msg, sig)

suite "Wallet":
  noFuzzTest "New Wallet without password.":
    verify(newWallet(""))

  noFuzzTest "New Wallet with password.":
    verify(newWallet("password"))

  noFuzzTest "Reloaded Wallet.":
    var
      wallet = newWallet("password")
      reloaded = newWallet(wallet.mnemonic.sentence, "password")

    check:
      wallet.mnemonic.entropy == reloaded.mnemonic.entropy
      wallet.mnemonic.checksum == reloaded.mnemonic.checksum
      wallet.mnemonic.sentence == reloaded.mnemonic.sentence

      wallet.hd.chainCode == reloaded.hd.chainCode
      wallet.hd.privateKey == reloaded.hd.privateKey
      wallet.hd.publicKey == reloaded.hd.publicKey
      wallet.hd.address == reloaded.hd.address
