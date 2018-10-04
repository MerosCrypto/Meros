#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#RPC object.
import ../objects/RPCObj

#Finals lib.
import finals

#JSON standard lib.
import json

#Set the Wallet's Private Key.
#The RPC method is set. Set is a keyword. The Nim proc is therefore expanded to setPrivateKey.
proc setPrivateKey(rpc: RPC, privateKey: string) {.raises: [ValueError, SodiumError].} =
    if privateKey.len == 0:
        rpc.wallet = newWallet()
    else:
        rpc.wallet = newWallet(newPrivateKey(privateKey))

#Get the Wallet info.
proc get(rpc: RPC) {.raises: [ChannelError].} =
    try:
        rpc.toGUI[].send(%* {
            "privateKey": $rpc.wallet.privateKey,
            "publicKey": $rpc.wallet.publicKey,
            "address": rpc.wallet.address
        })
    except:
        raise newException(ChannelError, "Could not send the Wallet info over the channel.")

#Handler.
proc `walletModule`*(
    rpc: RPC,
    json: JSONNode
) {.raises: [ValueError, SodiumError, ChannelError].} =
    #Switch based off the method.
    case json["method"].getStr():
        of "set":
            rpc.setPrivateKey(json["args"][0].getStr())
        of "get":
            rpc.get()
