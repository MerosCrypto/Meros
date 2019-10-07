discard """
This is named NetworkLibFunctionBox, not NetworkFunctionBox, `because GlobalFunctionBox` also defines a `NetworkFunctionBox`.
"""

#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Block lib.
import ../../Database/Merit/Block

#Message object.
import MessageObj

#Async standard lib.
import asyncdispatch

type NetworkLibFunctionBox* = ref object
    getNetworkID*: proc (): int {.noSideEffect, raises: [].}
    getProtocol*: proc (): int {.noSideEffect, raises: [].}
    getTail*: proc (): Hash[384] {.inline, raises: [].}

    handle*: proc (
        msg: Message
    ): Future[void]

    addBlock*: proc (
        newBlock: Block,
        syncing: bool = false
    ): Future[void]

func newNetworkLibFunctionBox*(): NetworkLibFunctionBox {.forceCheck: [].} =
    NetworkLibFunctionBox()
