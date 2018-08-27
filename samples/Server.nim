#Numerical libs.
import lib/BN
import lib/Base

#Wallet lib.
import Wallet/Wallet

#Lattice lib.
import Database/Lattice/Lattice

#Serialization libs.
import Network/Serialize/ParseSend
import Network/Serialize/ParseReceive

#Networking standard lib.
import net

var
    server: Socket = newSocket()     #Server Socket.
    client: Socket = new Socket      #Client Socket.
    minter: Wallet = newWallet()     #Wallet.
    lattice: Lattice = newLattice()  #Lattice.
    mintIndex: Index = lattice.mint( #Mint transaction.
        minter.getAddress(),
        newBN("1000000")
    )
    mintRecv: Receive = newReceive(  #Mint Receive.
        mintIndex,
        newBN("1000000"),
        newBN()
    )

#Sign and add the Mint Receive.
discard minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Print the Private Key and address of the address holding the coins.
echo minter.getAddress() &
    " was minted, and has received, one million coins. Its Private Key is " &
    $minter.getPrivateKey() &
    "."

#Handles a client.
proc handle(client: Socket) =
    echo "Handling a new client..."

    while true:
        #Read the socket data into the line var.
        var line: string = client.recvLine()
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
                    echo "Invalid Send."
                    continue

                #Print the message info.
                echo "Adding a new Send."
                echo "From:   " & send.getSender()
                echo "To:     " & send.getOutput()
                echo "Amount: " & $send.getAmount()
                echo "\r\n"

                #Print before-balance, if the Lattice accepts it, and the new balance.
                echo "Balance of " & send.getSender() & ":     " & $lattice.getBalance(send.getSender())
                echo "Adding: " &
                    $lattice.add(
                        send
                    )
                echo "New balance of " & send.getSender() & ": " & $lattice.getBalance(send.getSender())

            #Receive Node.
            of 1:
                var recv: Receive
                #Try to parse it.
                try:
                    recv = line.parseReceive()
                except:
                    echo "Invalid Receive."
                    continue

                #Print the message info.
                echo "Adding a new Receive."
                echo "From:   " & recv.getInputAddress()
                echo "To:     " & recv.getSender()
                echo "Amount: " & $recv.getAmount()
                echo "\r\n"

                #Print before-balance, if the Lattice accepts it, and the new balance.
                echo "Balance of " & recv.getSender() & ":     " & $lattice.getBalance(recv.getSender())
                echo "Adding: " &
                    $lattice.add(
                        recv
                    )
                echo "New balance of " & recv.getSender() & ": " & $lattice.getBalance(recv.getSender())

            #Unsupported message.
            else:
                echo "Unsupported message type."

server.setSockOpt(OptReuseAddr, true)
server.bindAddr(Port(5132))
server.listen()

while true:
    server.accept(client)
    handle(client)
    client = new Socket
