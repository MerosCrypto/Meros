#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Transactions lib (for all Transaction types).
import ../Database/Transactions/Transactions

#Element lib.
import ../Database/Consensus/Elements/Element

#Block lib.
import ../Database/Merit/Block

#Serialization libs.
import Serialize/Merit/SerializeBlockHeader
import Serialize/Merit/SerializeBlockBody

import Serialize/Transactions/SerializeClaim
import Serialize/Transactions/SerializeSend
import Serialize/Transactions/SerializeData

#Message object.
import objects/MessageObj

#Client lib and Clients object.
import Client
import objects/ClientsObj

#Export Client/ClientsObj.
export Client
export ClientsObj

#Network Function Box.
import objects/NetworkLibFunctionBoxObj

#Networking standard libs.
import asyncdispatch, asyncnet

#Handle a client.
proc handle(
    client: Client,
    networkFunctions: NetworkLibFunctionBox
) {.forceCheck: [
    IndexError,
    ClientError
], async.} =
    #Message loop variable.
    var msg: Message

    #While the client is still connected...
    while not client.isClosed():
        #Read in a new message.
        try:
            msg = await client.recv()
        except ClientError as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Receiving a message from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #If this was a message changing the sync state, update it and continue.
        if msg.content == MessageType.Syncing:
            client.remoteSync = true

            #Send SyncingAcknowledged.
            try:
                await client.send(newMessage(MessageType.SyncingAcknowledged))
            except ClientError as e:
                fcRaise e
            except Exception as e:
                doAssert(false, "Sending a `SyncingAcknowledged` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

            #Handle the syncing messages.
            while (not client.isClosed()) and client.remoteSync:
                #Read in a new message.
                try:
                    msg = await client.recv()
                except ClientError as e:
                    fcRaise e
                except Exception as e:
                    doAssert(false, "Receiving a message from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Switch based off the message type.
                case msg.content:
                    of MessageType.Handshake:
                        try:
                            await client.send(newMessage(MessageType.BlockchainTail, networkFunctions.getTail().toString()))
                        except ClientError as e:
                            fcRaise e
                        except Exception as e:
                            doAssert(false, "Sending a `BlockchainTail` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

                    of MessageType.BlockListRequest:
                        doAssert(false)

                    of MessageType.BlockHeaderRequest:
                        var header: BlockHeader
                        try:
                            try:
                                header = networkFunctions.getBlock(msg.message.toHash(384)).header
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 48-byte message to a 48-byte hash: " & e.msg)

                            try:
                                await client.send(newMessage(MessageType.BlockHeader, header.serialize()))
                            except ClientError as e:
                                fcRaise e
                            except Exception as e:
                                doAssert(false, "Sending a `BlockHeader` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)
                        except IndexError:
                            try:
                                await client.send(newMessage(MessageType.DataMissing))
                            except ClientError as e:
                                fcRaise e
                            except Exception as e:
                                doAssert(false, "Sending a `DataMissing` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

                    of MessageType.BlockBodyRequest:
                        var body: BlockBody
                        try:
                            try:
                                body = networkFunctions.getBlock(msg.message.toHash(384)).body
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 48-byte message to a 48-byte hash: " & e.msg)

                            try:
                                await client.send(newMessage(MessageType.BlockBody, body.serialize()))
                            except ClientError as e:
                                fcRaise e
                            except Exception as e:
                                doAssert(false, "Sending a `BlockBody` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)
                        except IndexError:
                            try:
                                await client.send(newMessage(MessageType.DataMissing))
                            except ClientError as e:
                                fcRaise e
                            except Exception as e:
                                doAssert(false, "Sending a `DataMissing` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

                    of MessageType.VerificationPacketRequest:
                        doAssert(false)

                    of MessageType.TransactionRequest:
                        var tx: Transaction
                        try:
                            try:
                                tx = networkFunctions.getTransaction(msg.message.toHash(384))
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 48-byte message to a 48-byte hash: " & e.msg)

                            var content: MessageType
                            try:
                                case tx:
                                    of Mint as _:
                                        raise newException(IndexError, "TransactionRequest asked for a Mint.")
                                    of Claim as _:
                                        content = MessageType.Claim
                                    of Send as _:
                                        content = MessageType.Send
                                    of Data as _:
                                        content = MessageType.Data
                                    else:
                                        doAssert(false, "Responding with an unsupported Transaction type to a TransactionRequest.")
                                await client.send(newMessage(content, tx.serialize()))
                            except ClientError as e:
                                fcRaise e
                            except Exception as e:
                                doAssert(false, "Sending a `BlockBody` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)
                        except IndexError:
                            try:
                                await client.send(newMessage(MessageType.DataMissing))
                            except ClientError as e:
                                fcRaise e
                            except Exception as e:
                                doAssert(false, "Sending a `DataMissing` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

                    of MessageType.SyncingOver:
                        client.remoteSync = false

                    else:
                        raise newException(ClientError, "Client sent a message which can't be sent during syncing during syncing.")
        else:
            #Handle our new message.
            try:
                await networkFunctions.handle(msg)
            except IndexError as e:
                fcRaise e
            except ClientError as e:
                fcRaise e
            except Spam:
                continue
            except Exception as e:
                doAssert(false, "Handling a message threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Add a new Client from a Socket.
proc add*(
    clients: Clients,
    ip: string,
    port: int,
    server: bool,
    socket: AsyncSocket,
    networkFunctions: NetworkLibFunctionBox
) {.forceCheck: [], async.} =
    #Create the Client.
    var client: Client = newClient(
        ip,
        port,
        clients.count,
        socket
    )
    #Increase the count so the next client has an unique ID.
    inc(clients.count)

    #Handshake with the Client.
    try:
        await client.handshake(
            networkFunctions.getNetworkID(),
            networkFunctions.getProtocol(),
            server,
            networkFunctions.getTail()
        )
    except ClientError:
        client.close()
        return
    except Exception as e:
        doAssert(false, "Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Add the new Client to Clients.
    clients.add(client)

    #Add a repeating timer which confirms this node is active.
    try:
        addTimer(
            20000,
            false,
            proc (
                fd: AsyncFD
            ): bool {.forceCheck: [].} =
                if client.last + 60 <= getTime():
                    client.close()
                elif client.last + 40 <= getTime():
                    try:
                        asyncCheck (
                            proc (): Future[void] {.forceCheck: [], async.} =
                                if client.remoteSync == true:
                                    return

                                var tail: Hash[384]
                                {.gcsafe.}:
                                    tail = networkFunctions.getTail()

                                try:
                                    await client.send(
                                        newMessage(
                                            MessageType.Handshake,
                                            char(networkFunctions.getNetworkID()) &
                                            char(networkFunctions.getProtocol()) &
                                            (if server: char(1) else: char(0)) &
                                            tail.toString()
                                        )
                                    )
                                except ClientError:
                                    client.close()
                                except Exception as e:
                                    doAssert(false, "Sending to a client threw an Exception despite catching all thrown Exceptions: " & e.msg)
                        )()
                    except Exception as e:
                        doAssert(false, "Calling a function to send a keep-alive to a client threw an Exception despite catching all thrown Exceptions: " & e.msg)
        )
    except OSError as e:
        doAssert(false, "Couldn't set a timer due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't set a timer due to an Exception: " & e.msg)

    #Handle it.
    try:
        await client.handle(networkFunctions)
    #If an IndexError happened, we couldn't get the Client to reply to them.
    #This means something else disconnected and removed them.
    except IndexError:
        #Disconnect them again to be safe.
        clients.disconnect(client.id)
    except ClientError:
        clients.disconnect(client.id)
    except Exception as e:
        doAssert(false, "Handling a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Reply to a message.
proc reply*(
    clients: Clients,
    msg: Message,
    res: Message
) {.forceCheck: [
    IndexError
], async.} =
    #Get the client.
    var client: Client
    try:
        client = clients[msg.client]
    except IndexError as e:
        fcRaise e

    #Try to send the message.
    try:
        await client.send(res)
    #If that failed, disconnect the client.
    except ClientError:
        clients.disconnect(client.id)
    except Exception as e:
        doAssert(false, "Replying to a message threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Broadcast a message to all clients.
proc broadcast*(
    clients: Clients,
    msg: Message
) {.forceCheck: [], async.} =
    #Iterate over each client.
    for client in clients.notSyncing:
        #Skip the Client who sent us this.
        if client.id == msg.client:
            continue

        #Try to send the message.
        try:
            await client.send(msg)
        #If that failed, mark the Client for disconnection.
        except ClientError:
            clients.disconnect(client.id)
        except Exception as e:
            doAssert(false, "Broadcasting a message to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)
