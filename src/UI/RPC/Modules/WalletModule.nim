#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#Finals lib.
import finals

#JSON standard lib.
import json

#Get the Wallet info.
func getWallet(rpc: RPC): JSONNode {.raises: [EventError, PersonalError].} =
    var wallet: Wallet
    try:
        wallet = rpc.events.get(
            proc (): Wallet,
            "personal.getWallet"
        )()
    except:
        raise newException(EventError, "Couldn't get and call personal.get.")
    if wallet == nil:
        raise newException(PersonalError, "Personal doesn't have a Wallet.")

    result = %* {
        "seed": $wallet.seed,
        "publicKey": $wallet.publicKey,
        "address": wallet.address
    }

#Set the Wallet's Seed.
#The RPC method is set. Set is a keyword. The Nim func is therefore expanded to setPrivateKey.
proc setSeed(
    rpc: RPC,
    seed: string
): JSONNode {.raises: [
    EventError,
].} =
    try:
        rpc.events.get(
            proc (seed: string),
            "personal.setSeed"
        )(seed)
    except:
        raise newException(EventError, "Couldn't get and call personal.setSeed.")

#Handler.
proc `walletModule`*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.raises: [].} =
    #Declare a var for the response.
    var res: JSONNode

    #Put this in a try/catch in case the method fails.
    try:
        #Switch based off the method.
        case json["method"].getStr():
            of "setSeed":
                res = rpc.setSeed(json["args"][0].getStr())

            of "getWallet":
                res = rpc.getWallet()

            else:
                res = %* {
                    "error": "Invalid method."
                }
    except:
        #If there was an issue, make the response the error message.
        res = %* {
            "error": getCurrentExceptionMsg()
        }

    reply(res)
