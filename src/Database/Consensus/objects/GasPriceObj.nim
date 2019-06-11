import ../../../lib/Errors

import ../../../lib/hash

import finals

import ElementObj

finalsd:
    type
        GasPrice* = ref object of Element
            price* {.final.}: uint32

        SignedGasPrice* = ref object of GasPrice
            signature* {.final.}: BLSSignature

func newGasPrice*(
    price: int
): GasPrice {.forceCheck: [].} =
    result = GasPrice(
        price: price
    )
    result.ffinalizePrice()

func newSignedGasPrice*(
    price: int
): SignedGasPrice {.forceCheck: [].} =
    result = SignedGasPrice(
        price: price
    )
    result.ffinalizePrice()
