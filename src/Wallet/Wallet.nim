discard """
var
    privKey: PrivateKey = newPrivateKey()
    pubKey: PublicKey = newPublicKey(privKey)
    privKey2: PrivateKey = newPrivateKey()
    pubKey2: PublicKey = newPublicKey(privKey2)

echo pubKey

var str: string = "test"

echo pubKey.verify(str, privKey.sign(str))
echo pubKey2.verify(str, privKey.sign(str))
"""
