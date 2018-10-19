#BLS wrapper that adds a prefix to the types.

import ec_bls

type
    BLSPrivateKey* = PrivateKey
    BLSPublicKey* = PublicKey
    BLSSignature* = Signature
    BLSAggregationInfo* = AggregationInfo

#Constructors.
let
    newBLSPrivateKeyFromSeed*: func (
        key: string
    ): PrivateKey = newPrivateKeyFromSeed

    newBLSPrivateKeyFromBytes*: func (
        key: string
    ): PrivateKey = newPrivateKeyFromBytes

    newBLSPublicKey*: func (
        key: string
    ): PublicKey = newPublicKeyFromBytes

    newBLSSignature*: func (
        sig: string
    ): Signature = newSignatureFromBytes

    newBLSAggregationInfo*: func (
        key: BLSPublicKey,
        msg: string
    ): AggregationInfo = newAggregationInfoFromMsg

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
export aggregate
