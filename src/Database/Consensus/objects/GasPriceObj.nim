import ../../../lib/Errors

import ../../../Wallet/BLS

import ../../../lib/Hash

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
    price: uint32
): GasPrice {.forceCheck: [].} =
    result = GasPrice(
        price: price
    )
    result.ffinalizePrice()

func newSignedGasPriceObj*(
    price: uint32
): SignedGasPrice {.forceCheck: [].} =
    result = SignedGasPrice(
        price: price
    )
    result.ffinalizePrice()
