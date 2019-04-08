#Errors lib.
import ../lib/Errors

#BLS Nimble package.
import mc_bls

#Type aliases.
type
    BLSPrivateKey* = PrivateKey
    BLSPublicKey* = PublicKey
    BLSSignature* = Signature
    BLSAggregationInfo* = AggregationInfo

#Constructors.
proc newBLSPrivateKeyFromSeed*(
    key: string
): BLSPrivateKey {.forceCheck: [
    BLSError
].} =
    try:
        result = newPrivateKeyFromSeed(key)
    except:
        raise newException(BLSError, "Couldn't create a BLS Private Key from a Seed: " & getCurrentExceptionMsg())

proc newBLSPrivateKeyFromBytes*(
    key: string
): BLSPrivateKey {.forceCheck: [
    BLSError
].} =
    try:
        result = newPrivateKeyFromBytes(key)
    except:
        raise newException(BLSError, "Couldn't create a BLS Private Key from its Bytes: " & getCurrentExceptionMsg())

proc getPublicKey*(
    key: BLSPrivateKey
): BLSPublicKey {.forceCheck: [
    BLSError
].} =
    try:
        result = mc_bls.getPublicKey(key)
    except:
        raise newException(BLSError, "Couldn't create a BLS Public Key from a Private Key: " & getCurrentExceptionMsg())

proc newBLSPublicKey*(
    key: string
): BLSPublicKey {.forceCheck: [
    BLSError
].} =
    try:
        result = newPublicKeyFromBytes(key)
    except:
        raise newException(
            BLSError,
            "Couldn't create a BLS Public Key from its Bytes: " & getCurrentExceptionMsg()
        )

proc newBLSSignature*(
    sig: string
): BLSSignature {.forceCheck: [
    BLSError
].} =
    try:
        result = newSignatureFromBytes(sig)
    except:
        raise newException(
            BLSError,
            "Couldn't create a BLS Signature from its Bytes: " & getCurrentExceptionMsg()
        )

proc newBLSAggregationInfo*(
    key: BLSPublicKey,
    msg: string
): BLSAggregationInfo {.forceCheck: [BLSError].} =
    try:
        result = newAggregationInfoFromMsg(key, msg)
    except:
        raise newException(
            BLSError,
            "Couldn't create a BLS AggregationInfo from a Message: " & getCurrentExceptionMsg()
        )

#Getters.
export getAggregationInfo

#Equality operators.
export `==`
export `!=`

#Stringify functions.
export toString
export `$`

#Signature functions.
export setAggregationInfo
export verify

#Private Key functions.
proc sign*(key: BLSPrivateKey, msg: string): BLSSignature {.forceCheck: [BLSError].} =
    try:
        result = mc_bls.sign(key, msg)
    except:
        raise newException(BLSError, "Couldn't sign a message: " & getCurrentExceptionMsg())

#Aggregation functions.
proc aggregate*(keys: seq[BLSPublicKey]): BLSPublicKey {.forceCheck: [BLSError].} =
    try:
        result = mc_bls.aggregate(keys)
    except:
        raise newException(
            BLSError,
            "Couldn't aggregate the BLS Public Keys: " & getCurrentExceptionMsg()
        )

proc aggregate*(
    agInfos: seq[BLSAggregationInfo]
): BLSAggregationInfo {.forceCheck: [BLSError].} =
    try:
        result = mc_bls.aggregate(agInfos)
    except:
        raise newException(
            BLSError,
            "Couldn't aggregate the BLS AggregationInfos: " & getCurrentExceptionMsg()
        )

proc aggregate*(sigs: seq[BLSSignature]): BLSSignature {.forceCheck: [BLSError].} =
    try:
        result = mc_bls.aggregate(sigs)
    except:
        raise newException(
            BLSError,
            "Couldn't aggregate the BLS Signatures: " & getCurrentExceptionMsg()
        )
