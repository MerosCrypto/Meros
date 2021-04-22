import strutils

import ../../src/Wallet/Ed25519
import ../../src/Wallet/Wallet

import ../Fuzzed

suite "Ed25519":
  setup:
    var keys: seq[EdPublicKey] = @[
      newEdPublicKey(parseHexStr("0210EEDF740C1EFD7727BE80458ECA7D171EDD1CDCA77A97A9DBE8B7BDCDF28B")),
      newEdPublicKey(parseHexStr("91841823E21F80D0514027DA146888DE26A37FD5FC41E8632CC91414602E2F9F"))
    ]

  noFuzzTest "Aggregate.":
    check keys.aggregate() == newEdPublicKey(parseHexStr("F19E50A37AB431A12E2DB0E1214A40D7845A1551FFAB50A0D7D25BC5D1E72AFC"))

  noFuzzTest "Doesn't aggregate a single key.":
    check @[keys[0]].aggregate() == keys[0]

  noFuzzTest "Doesn't aggregate the same key.":
    check @[keys[0], keys[0]].aggregate() == keys[0]

  noFuzzTest "Does aggregate the same key with other keys.":
    check @[keys[0], keys[1], keys[0]].aggregate() == newEdPublicKey(parseHexStr("63408405F1D65043158A56B48C849A865AAAF6D8E7D0CE3A67C623D32E634019"))

  noFuzzTest "Can create the private key for an aggregated public key.":
    let
      a: EdPrivateKey = newWallet("").hd.privateKey
      b: EdPrivateKey = newWallet("").hd.privateKey
    check @[a, b].aggregate().toPublicKey() == @[a.toPublicKey(), b.toPublicKey()].aggregate()
