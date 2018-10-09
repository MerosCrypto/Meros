#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Wallet lib.
import ../../../Wallet/Wallet

#Lattice lib.
import ../../../Database/Lattice/Lattice

#Message lib.
import ../../../Network/objects/MessageObj

#Serialization libs.
import ../../../Network/Serialize/SerializeSend
import ../../../Network/Serialize/SerializeReceive

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

#Create a Send Node.
proc send(
    rpc: RPC,
    address: string,
    amount: BN,
    nonce: BN
) {.raises: [
    ValueError,
    ArgonError,
    SodiumError,
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
    if not rpc.wallet.sign(send):
        raise newException(PersonalError, "RPC couldn't create and sign a send.")

    try:
        #Add it.
        if rpc.events.get(
            proc (send: Send): bool,
            "lattice.send"
        )(send):
            #If it worked, broadcast the Send.
            rpc.events.get(
                proc (msgType: MessageType, msg: string),
                "network.broadcast"
            )(MessageType.Send, send.serialize())
    except:
        raise newException(EventError, "Couldn't get and call lattice.send.")

#Create a Receive Node.
proc receive(
    rpc: RPC,
    address: string,
    inputNonce: BN,
    nonce: BN
) {.raises: [
    ValueError,
    SodiumError,
    EventError,
    FinalAttributeError
].} =
    #Create the Receive.
    var recv: Receive = newReceive(
        address,
        inputNonce,
        nonce
    )
    #Sign the Receive.
    rpc.wallet.sign(recv)

    try:
        #Add it.
        if rpc.events.get(
            proc (recv: Receive): bool,
            "lattice.receive"
        )(recv):
            try:
                #If it worked, broadcast the Receive.
                rpc.events.get(
                    proc (msgType: MessageType, msg: string),
                    "network.broadcast"
                )(MessageType.Receive, recv.serialize())
            except:
                raise newException(EventError, "Couldn't get and call network.broadcast.")
    except:
        raise newException(EventError, "Couldn't get and call lattice.receive.")

#Get the height of an account.
proc getHeight(
    rpc: RPC,
    account: string
) {.raises: [
    EventError,
    ChannelError
].} =
    #Get the height.
    var height: BN

    try:
        height = rpc.events.get(
            proc (account: string): BN,
            "lattice.getHeight"
        )(account)
    except:
        raise newException(EventError, "Couldn't get and call lattice.getHeight.")

    try:
        #Send back the height.
        rpc.toGUI[].send(%* {
            "height": $height
        })
    except:
        raise newException(ChannelError, "Could not send the height over the channel.")

#Get the balance of an account.
proc getBalance(
    rpc: RPC,
    account: string
) {.raises: [
    ChannelError,
    EventError
].} =
    #Get the balance.
    var balance: BN
    try:
        balance = rpc.events.get(
            proc (account: string): BN,
            "lattice.getBalance"
        )(account)
    except:
        raise newException(EventError, "Couldn't get and call lattice.getBalance.")

    try:
        #Send back the balance.
        rpc.toGUI[].send(%* {
            "balance": $balance
        })
    except:
        raise newException(ChannelError, "Could not send the balance over the channel.")

#Handler.
proc `latticeModule`*(
    rpc: RPC,
    json: JSONNode
) {.raises: [
    ValueError,
    ArgonError,
    SodiumError,
    PersonalError,
    ChannelError,
    EventError,
    FinalAttributeError
].} =
    #Switch based off the method.
    case json["method"].getStr():
        of "send":
            rpc.send(
                json["args"][0].getStr(),
                newBN(json["args"][1].getStr()),
                newBN(json["args"][2].getStr())
            )

        of "receive":
            rpc.receive(
                json["args"][0].getStr(),
                newBN(json["args"][1].getStr()),
                newBN(json["args"][2].getStr())
            )

        of "getHeight":
            rpc.getHeight(
                json["args"][0].getStr()
            )

        of "getBalance":
            rpc.getBalance(
                json["args"][0].getStr()
            )
