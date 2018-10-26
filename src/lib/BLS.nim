#BLS wrapper that adds a prefix to the types.

#Errors lib.
import Errors

#BLS Nimble package.
import ec_bls

#Type definitions.
type
    BLSPrivateKey* = PrivateKey
    BLSPublicKey* = PublicKey
    BLSSignature* = Signature
    BLSAggregationInfo* = AggregationInfo

#Constructors.
proc newBLSPrivateKeyFromSeed*(key: string): BLSPrivateKey {.raises: [BLSError].} =
    try:
        result = newPrivateKeyFromSeed(key)
    except:
        raise newException(
            BLSError,
            "Couldn't create a BLS Private Key from a Seed: " & getCurrentExceptionMsg()
        )

proc newBLSPrivateKeyFromBytes*(key: string): BLSPrivateKey {.raises: [BLSError].} =
    try:
        result = newPrivateKeyFromBytes(key)
    except:
        raise newException(
            BLSError,
            "Couldn't create a BLS Private Key from its Bytes: " & getCurrentExceptionMsg()
        )

proc newBLSPublicKey*(key: string): BLSPublicKey {.raises: [BLSError].} =
    try:
        result = newPublicKeyFromBytes(key)
    except:
        raise newException(
            BLSError,
            "Couldn't create a BLS Public Key from its Bytes: " & getCurrentExceptionMsg()
        )

proc newBLSSignature*(sig: string): BLSSignature {.raises: [BLSError].} =
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
): BLSAggregationInfo {.raises: [BLSError].} =
    try:
        result = newAggregationInfoFromMsg(key, msg)
    except:
        raise newException(
            BLSError,
            "Couldn't create a BLS AggregationInfo from a Message: " & getCurrentExceptionMsg()
        )

#Getters.
export getPublicKey
export getAggregationInfo

#Equality operators.
export `==`
export `!=`

#Stringify functions.
export toString
export `$`

#Private Key functions.
export sign

#Signature functions.
export setAggregationInfo
export verify

#Aggregation functions.
proc aggregate*(keys: seq[BLSPublicKey]): BLSPublicKey {.raises: [BLSError].} =
    try:
        result = ec_bls.aggregate(keys)
    except:
        raise newException(
            BLSError,
            "Couldn't aggregate the BLS Public Keys: " & getCurrentExceptionMsg()
        )

proc aggregate*(
    agInfos: seq[BLSAggregationInfo]
): BLSAggregationInfo {.raises: [BLSError].} =
    try:
        result = ec_bls.aggregate(agInfos)
    except:
        raise newException(
            BLSError,
            "Couldn't aggregate the BLS AggregationInfos: " & getCurrentExceptionMsg()
        )

proc aggregate*(sigs: seq[BLSSignature]): BLSSignature {.raises: [BLSError].} =
    try:
        result = ec_bls.aggregate(sigs)
    except:
        raise newException(
            BLSError,
            "Couldn't aggregate the BLS Signatures: " & getCurrentExceptionMsg()
        )
