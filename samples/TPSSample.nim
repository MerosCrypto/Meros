#Numerical libs.
import BN
import ../src/lib/Base

#Wallet lib.
import ../src/Wallet/Wallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#Serialization libs.
import ../src/Network/Serialize/SerializeSend
import ../src/Network/Serialize/SerializeReceive

#Parsing libs.
import ../src/Network/Serialize/ParseSend
import ../src/Network/Serialize/ParseReceive

#Networking standard libs.
import asyncnet, asyncdispatch

#Times standard lib.
import times

var
    #Testing vars.
    total: int = 10000 #Total number of transactions to make.
    txCount: int = 0  #Count of the handled transactions.
    start: float      #Start time.

    #Server vars.
    server: AsyncSocket = newAsyncSocket() #Server Socket.
    minter: Wallet = newWallet()           #Wallet.
    lattice: Lattice = newLattice()        #Lattice.
    mintIndex: Index = lattice.mint(       #Mint transaction.
        minter.address,
        newBN("1000000")
    )
    mintRecv: Receive = newReceive(        #Mint Receive.
        mintIndex,
        newBN()
    )

    #Client vars.
    receiver: Wallet = newWallet()                       #Address to send to.
    sends: seq[Send] = @[]                               #Send objects.
    recvs: seq[Receive] = @[]                            #Receive objects.
    sendHeader: string =                                 #Send header.
        $(char(0)) &
        $(char(0)) &
        $(char(0))
    recvHeader: string =                                 #Receive header.
        $(char(0)) &
        $(char(0)) &
        $(char(1))
    serializedSends: seq[string] = newSeq[string](total) #Serialized sends.
    serializedRecvs: seq[string] = newSeq[string](total) #Serialized Receives.
    client: AsyncSocket = newAsyncSocket()               #Client socket.

#Sign and add the Mint Receive.
minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Handles a client.
proc handle(client: AsyncSocket) {.async.} =
    #Define the loop variables outside of the loops.
    var
        header: string
        line: string
        network: int
        version: int
        msgType: int
        msgLength: int

    while true:
        #Read the header.
        header = await client.recv(4)
        #Verify the length.
        if header.len != 4:
            echo "Invalid Header Length."
            continue

        #Parse the header.
        network = ord(header[0])
        version = ord(header[1])
        msgType = ord(header[2])
        msgLength = ord(header[3])

        #Read the line.
        line = await client.recv(msgLength)
        #Verify the length.
        if line.len != msgLength:
            echo "Invalid Message Length."
            continue

        #Handle the different message types.
        case msgType:
            #Send Node.
            of 0:
                var send: Send
                #Try to parse it.
                try:
                    send = line.parseSend()
                except:
                    echo "Invalid Send. " & getCurrentExceptionMsg()
                    continue

                #Add the Send.
                if lattice.add(send):
                    #Increase the TX count.
                    inc(txCount)

            of 1:
                var recv: Receive
                #Try to parse it.
                try:
                    recv = line.parseReceive()
                except:
                    echo "Invalid Receive. " & getCurrentExceptionMsg()
                    continue

                #Add the Receive.
                if lattice.add(recv):
                    #Increase the TX count.
                    inc(txCount)

                    #If this is the last TX...
                    if txCount == total:
                        #Print the TPS.
                        echo "TPS: " & $(float(txCount) / (cpuTime() - start))

            #Unsupported message.
            else:
                echo "Unsupported message type."

#Start listening.
server.setSockOpt(OptReuseAddr, true)
server.bindAddr(Port(5132))
server.listen()

#Async function wrapper.
proc accept() {.async.} =
    #Accept new connections infinitely.
    while true:
        asyncCheck handle(await server.accept())

#Async function to spam the server.
proc spam() {.async.} =
    #Start the timer.
    start = cpuTime()

    #Define the serialized var.
    var serialized: string

    #Generate the Send/Receive pairs.
    for i in 0 ..< total:
        #Generate the Send.
        sends.add(
            newSend(
                receiver.address,
                BNNums.ONE,
                newBN(i + 1)
            )
        )

        #Mine the Send.
        sends[i].mine(lattice.difficulties.transaction)
        #Sign the Send.
        discard minter.sign(sends[i])

        #Generate the Receive.
        recvs.add(
            newReceive(
                minter.address,
                newBN(i + 1),
                newBN(i)
            )
        )
        #Sign the Receive.
        receiver.sign(recvs[i])

        #Serialize them, and turn them into network encoded data.
        serialized = sends[i].serialize()
        serializedSends[i] = sendHeader & $char(serialized.len) & serialized
        serialized = recvs[i].serialize()
        serializedRecvs[i] = recvHeader & $char(serialized.len) & serialized

    #Print the time to generate the pairs.
    echo "Generated " & $total & " Send/Receive pairs in " & $(cpuTime() - start) & " seconds."
    #Restart the timer.
    start = cpuTime()

    #Connect to the server.
    await client.connect("127.0.0.1", Port(5132))
    #Iterate over the serialized Sends/Receives.
    for i in 0 ..< total:
        await client.send(serializedSends[i])
        await client.send(serializedRecvs[i])
    #Print we sent them.
    echo "Sent all " & $total & "."

#Start the Server.
asyncCheck accept()
#Generate the spam.
asyncCheck spam()

#Run forever.
runForever()
