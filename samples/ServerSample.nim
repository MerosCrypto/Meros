#BN lib.
import BN

#Wallet lib.
import ../src/Wallet/Wallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#Serialization libs.
import ../src/Network/Serialize/ParseSend
import ../src/Network/Serialize/ParseReceive

#SetOnce lib.
import SetOnce

#Networking standard libs.
import asyncnet, asyncdispatch

var
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

#Sign and add the Mint Receive.
minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Print the Private Key and address of the address holding the coins.
echo minter.address &
    " was minted, and has received, one million coins. Its Private Key is " &
    $minter.privateKey.toValue() & "."

#Handles a client.
proc handle(client: AsyncSocket) {.async.} =
    echo "Handling a new client..."

    while true:
        #Read the socket data into the line var.
        var line: string = await client.recvLine()
        if line.len == 0:
            return

        var
            #Extract the header.
            header: string = line.substr(0, 3)
            #Parse the header.
            network:   int = int(header[0])
            version:   int = int(header[1])
            msgType:   int = int(header[2])
            msgLength: int = int(header[3])
        #Remove the header.
        line = line.substr(4, line.len)

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

                #Print the message info.
                echo "Adding a new Send."
                echo "From:   " & send.sender
                echo "To:     " & send.output
                echo "Amount: " & $send.amount.toValue()
                echo "\r\n"

                #Print before-balance, if the Lattice accepts it, and the new balance.
                echo "Balance of " & send.sender & ":     " & $lattice.getBalance(send.sender)
                echo "Adding: " &
                    $lattice.add(
                        send
                    )
                echo "New balance of " & send.sender & ": " & $lattice.getBalance(send.sender)

            #Receive Node.
            of 1:
                var recv: Receive
                #Try to parse it.
                try:
                    recv = line.parseReceive()
                except:
                    echo "Invalid Receive. " & getCurrentExceptionMsg()
                    continue

                #Print the message info.
                echo "Adding a new Receive."
                echo "From:   " & recv.inputAddress
                echo "To:     " & recv.sender
                echo "\r\n"

                #Print before-balance, if the Lattice accepts it, and the new balance.
                echo "Balance of " & recv.sender & ":     " & $lattice.getBalance(recv.sender)
                echo "Adding: " &
                    $lattice.add(
                        recv
                    )
                echo "New balance of " & recv.sender & ": " & $lattice.getBalance(recv.sender) & "\r\n"

            #Unsupported message.
            else:
                echo "Unsupported message type."

#Start listening.
server.setSockOpt(OptReuseAddr, true)
server.bindAddr(Port(5132))
server.listen()

#Accept new connections infinitely.
while true:
    asyncCheck handle(waitFor server.accept())
