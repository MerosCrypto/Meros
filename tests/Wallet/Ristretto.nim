import strutils

import ../../src/Wallet/Ristretto
import ../../src/Wallet/Wallet

import ../Fuzzed

suite "Ristretto":
  setup:
    var keys: seq[RistrettoPrivateKey] = @[
      newRistrettoPrivateKey(cast[seq[byte]](parseHexStr("FFC155FAC6D4AD58FD116B4ABC3F718D73CEFB91F2DCEF341B849FE7779C6F02"))),
      newRistrettoPrivateKey(cast[seq[byte]](parseHexStr("80BF74118A10F3880A3FC148AAE5B89391C4CFFA86411FAC0AF8D18B3229230B")))
    ]

  noFuzzTest "Aggregate.":
    check @[
      keys[0].toPublicKey(),
      keys[1].toPublicKey()
    ].aggregate() == newRistrettoPublicKey(parseHexStr("D0B1A60E9FD9AE0E643D179A967B8E33E8C3036BDE6FEFD3274776BE2AED8257"))

  noFuzzTest "Doesn't aggregate a single key.":
    check @[keys[0].toPublicKey()].aggregate() == keys[0].toPublicKey()

  noFuzzTest "Doesn't aggregate the same key.":
    check @[keys[0].toPublicKey(), keys[0].toPublicKey()].aggregate() == keys[0].toPublicKey()

  noFuzzTest "Does aggregate the same key with other keys.":
    check @[
      keys[0].toPublicKey(),
      keys[1].toPublicKey(),
      keys[0].toPublicKey()
    ].aggregate() == newRistrettoPublicKey(parseHexStr("50B39F0E9B94447ECFE47F99A8623255F93814B16397A246AF22C49AFC9C3A3F"))

  noFuzzTest "Can create the aggregated private key for the above vectors.":
    check keys.aggregate().toPublicKey() == @[keys[0].toPublicKey(), keys[1].toPublicKey()].aggregate()

  highFuzzTest "Can create the private key for an aggregated public key.":
    let
      a: RistrettoPrivateKey = newWallet("").hd.privateKey
      b: RistrettoPrivateKey = newWallet("").hd.privateKey
    check @[a, b].aggregate().toPublicKey() == @[a.toPublicKey(), b.toPublicKey()].aggregate()
