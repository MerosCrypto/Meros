#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Wallet lib.
import ../../../Wallet/Wallet

#Lattice lib.
import ../../../Database/Lattice/Lattice

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#Finals lib.
import finals

#String utils standard lib.
import strutils

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

#Create a Send Entry.
proc send(
    rpc: RPC,
    address: string,
    amount: BN,
    nonce: uint
): JSONNode {.raises: [
    ValueError,
    ArgonError,
    PersonalError,
    EventError,
    FinalAttributeError
].} =
    #Create the Send.
    var send: Send = newSend(
        address,
        amount,
        nonce
    )
    #Mine the Send.
    send.mine("aa".repeat(64).toBN(16))

    #Sign the Send.
    var sign: proc(send: Send): bool
    try:
        sign = rpc.events.get(
            proc (send: Send): bool,
            "personal.signSend"
        )
    except:
        raise newException(EventError, "Couldn't get and call personal.signSend.")
    try:
        if not send.sign():
            raise newException(Exception, "")
    except:
        raise newException(PersonalError, "Couldn't sign the Send.")

    try:
        #Add it.
        discard rpc.events.get(
            proc (send: Send): bool,
            "lattice.send"
        )(send)
    except:
        raise newException(EventError, "Couldn't get and call lattice.send.")

    result = %* {
        "hash": $send.hash
    }

#Create a Receive Entry.
proc receive(
    rpc: RPC,
    address: string,
    inputNonce: uint,
    nonce: uint
): JSONNode {.raises: [
    ValueError,
    PersonalError,
    EventError,
    FinalAttributeError
].} =
    #Create the Receive.
    var recv: Receive = newReceive(
        newIndex(
            address,
            inputNonce,
        ),
        nonce
    )

    #Sign the Receive.
    var sign: proc(recv: Receive): bool
    try:
        sign = rpc.events.get(
            proc (recv: Receive): bool,
            "personal.signReceive"
        )
    except:
        raise newException(EventError, "Couldn't get and call personal.signReceive.")
    try:
        if not recv.sign():
            raise newException(Exception, "")
    except:
        raise newException(PersonalError, "Couldn't sign the Receive.")

    try:
        #Add it.
        rpc.events.get(
            discard proc (recv: Receive): bool,
            "lattice.receive"
        )(recv)
    except:
        raise newException(EventError, "Couldn't get and call lattice.receive.")

    result = %* {
        "hash": $recv.hash
    }

#Handler.
proc `personalModule`*(
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

            of "send":
                res = rpc.send(
                    json["args"][0].getStr(),
                    newBN(json["args"][1].getStr()),
                    parseUInt(json["args"][2].getStr())
                )

            of "receive":
                res = rpc.receive(
                    json["args"][0].getStr(),
                    parseUInt(json["args"][1].getStr()),
                    parseUInt(json["args"][2].getStr())
                )

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
