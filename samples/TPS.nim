#Util lib.
import lib/Util

#Numerical libs.
import BN
import lib/Base

#Wallet lib.
import Wallet/Wallet

#Lattice lib.
import Database/Lattice/Lattice

#Serialization libs.
import Network/Serialize/SerializeSend
import Network/Serialize/SerializeReceive

#Parsing libs.
import Network/Serialize/ParseSend
import Network/Serialize/ParseReceive

#Networking standard libs.
import asyncnet, asyncdispatch

#Times standard lib.
import times

var
    #Testing vars.
    total: int = 3000 #Total number of Send blocks to make.
    txCount: int = 0  #Count of the handled transactions.
    start: float      #Start time.

    #Server vars.
    server: AsyncSocket = newAsyncSocket() #Server Socket.
    minter: Wallet = newWallet()           #Wallet.
    lattice: Lattice = newLattice()        #Lattice.
    mintIndex: Index = lattice.mint(       #Mint transaction.
        minter.getAddress(),
        newBN("1000000")
    )
    mintRecv: Receive = newReceive(        #Mint Receive.
        mintIndex,
        newBN()
    )

    #Client vars.
    receiver: Wallet = newWallet()                       #Address to send to.
    sends: seq[Send] = newSeq[Send](total)               #Send objects.
    recvs: seq[Receive] = newSeq[Receive](total)         #Send objects.
    sendHeader: string =                                 #Send header.
        $(char(0)) &
        $(char(0)) &
        $(char(0)) &
        $(char(0)) &
        $(char(0))
    recvHeader: string =                                 #Receive header.
        $(char(0)) &
        $(char(0)) &
        $(char(0)) &
        $(char(1)) &
        $(char(0))
    serializedSends: seq[string] = newSeq[string](total) #Serialized sends.
    serializedRecvs: seq[string] = newSeq[string](total) #Serialized Receives.
    client: AsyncSocket = newAsyncSocket()               #Client socket.

#Sign and add the Mint Receive.
discard minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Handles a client.
proc handle(client: AsyncSocket) {.async.} =
    while true:
        #Read the socket data into the line var.
        var line: string = await client.recvLine()
        if line.len == 0:
            return

        var
            #Extract the header.
            header: string = line.substr(0, 4)
            #Parse the header.
            network:    int = int(header[0])
            minVersion: int = int(header[1])
            maxVersion: int = int(header[2])
            msgType:    int = int(header[3])
            msgLength:  int = int(header[4])
        #Remove the header.
        line = line.substr(5, line.len)

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

    #Generate the Send/Receive pairs.
    for i in 0 ..< total:
        #Generate the Send.
        sends[i] = newSend(
            receiver.getAddress(),
            BNNums.ONE,
            newBN(i + 1)
        )
        #Mine the Send.
        sends[i].mine(lattice.getTransactionDifficulty())
        #Sign the Send.
        discard minter.sign(sends[i])

        #Generate the Receive.
        recvs[i] = newReceive(
            minter.getAddress(),
            newBN(i + 1),
            newBN(i)
        )
        #Sign the Receive.
        discard receiver.sign(recvs[i])

        #Serialize them.
        serializedSends[i] = sendHeader & sends[i].serialize() & "\r\n"
        serializedRecvs[i] = recvHeader & recvs[i].serialize() & "\r\n"

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
