#Errors lib.
import ../lib/Errors

#Messsage and Client object.
import objects/MessageObj
import objects/ClientObj

#Export the Client object.
export ClientObj

#Networking sstandard libs.
import asyncdispatch, asyncnet

#Receive a message.
proc recv*(client: Client): Future[Message] {.async.} =
    var
        header: string
        size: int
        msg: string

    #Receive the header.
    header = await client.socket.recv(2)
    #Verify the length.
    if header.len != 2:
        #If the header length is 0 because the client disconnected...
        if header.len == 0:
            #Close the client.
            client.socket.close()
            #Stop trying to recv.
            return
        #Else, if we got a partial header, raise an exception.
        raise newException(SocketError, "Didn't get a full header.")

    #Define the size.
    size = ord(header[1])
    #While the last size char is 255, signifying there's more to the size...
    while ord(header[^1]) == 255:
        #Get a new byte.
        header &= await client.socket.recv(1)
        #Add it to the size.
        size += ord(header[^1])

    #Now that we know how long the message is, get it.
    msg = await client.socket.recv(size)
    #Verify the length.
    if msg.len != size:
        raise newException(SocketError, "Didn't get a full message.")

    #Create a Message out of the header/message and return it.
    result = newMessage(
        client.id,
        MessageType(header[0]),
        uint(size),
        header,
        msg
    )

#Send a messsage.
proc send*(client: Client, msg: Message) {.raises: [AsyncError].} =
    #Make sure the client is open.
    if not client.socket.isClosed():
        try:
            asyncCheck client.socket.send($msg)
        except:
            raise newException(AsyncError, "Couldn't broacast to a Client.")
    #If it isn't, mark the client for disconnection.
    else:
        raise newException(AsyncError, "Client was closed.")
