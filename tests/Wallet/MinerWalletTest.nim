import random

import ../../src/lib/Util

import ../../src/Wallet/MinerWallet

import ../Fuzzed

suite "MinerWallet":
  setup:
    var
      wallet: MinerWallet = newMinerWallet()
      reloaded: MinerWallet = newMinerWallet(wallet.privateKey.serialize())

  midFuzzTest "Recreating the Private Key.":
    check:
      newBLSPrivateKey(wallet.privateKey.serialize()).serialize() == wallet.privateKey.serialize()
      $newBLSPrivateKey(wallet.privateKey.serialize()) == $wallet.privateKey

  midFuzzTest "Recreating the Public Key.":
    check:
      newBLSPublicKey(wallet.publicKey.serialize()).serialize() == wallet.publicKey.serialize()
      $newBLSPublicKey(wallet.publicKey.serialize()) == $wallet.publicKey

  midFuzzTest "Reload the MinerWallet.":
    reloaded = newMinerWallet(wallet.privateKey.serialize())
    check:
      wallet.privateKey.serialize() == reloaded.privateKey.serialize()
      wallet.publicKey.serialize() == reloaded.publicKey.serialize()

  midFuzzTest "Messages.":
    var
      msg: string
      wSig: BLSSignature
      rSig: BLSSignature

    for _ in 0 ..< rand(100):
      msg &= char(rand(255))

    wSig = wallet.sign(msg)
    rSig = reloaded.sign(msg)

    check:
      wSig.serialize() == rSig.serialize()
      newBLSSignature(wSig.serialize()).serialize() == wSig.serialize()
      wSig.verify(newBLSAggregationInfo(wallet.publicKey, msg))
