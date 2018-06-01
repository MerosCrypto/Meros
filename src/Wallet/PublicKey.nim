import PrivateKey

import ../lib/SECP256K1

type PubKey* = ref object of RootObj
    secret: array[32, uint8]

proc newPubKey*(privKey: PrivKey): PubKey =
    result = PubKey()

proc newPubKey*(hex: string): PubKey =
    result = PubKey()

proc verify*(pubKey: PubKey, hex: string): bool =
    result = true
