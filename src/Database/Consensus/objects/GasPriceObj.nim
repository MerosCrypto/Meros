import ../../../lib/Errors

import ../../../Wallet/BLS

import ../../../lib/hash

import finals

import ElementObj
export ElementObj

finalsd:
    type
        GasPrice* = ref object of Element
            price* {.final.}: uint32

        SignedGasPrice* = ref object of GasPrice
            signature* {.final.}: BLSSignature

func newGasPriceObj*(
    price: int
): GasPrice {.forceCheck: [].} =
    result = GasPrice(
        price: price
    )
    result.ffinalizePrice()

func newSignedGasPriceObj*(
    price: int
): SignedGasPrice {.forceCheck: [].} =
    result = SignedGasPrice(
        price: price
    )
    result.ffinalizePrice()
