discard """
This object file has a couple of pecularities.
1) It does not end with `Obj`. This is to match MainFunctionBox, which is also special.
2) It is named NetworkLibFB, not NetworkFB. This is because MFB also defines a `NetworkFunctionBox`.
"""

#Message object.
import MessageObj

#Async standard lib.
import asyncdispatch

type NetworkLibFunctionBox* = ref object of RootObj
    getNetworkID*: proc (): uint {.raises: [].}
    getProtocol*:  proc (): uint {.raises: [].}
    getHeight*:    proc (): uint {.raises: [].}

    handle*: proc (msg: Message): Future[bool]

proc newNetworkLibFunctionBox*(): NetworkLibFunctionBox {.raises: [].} =
    NetworkLibFunctionBox()
