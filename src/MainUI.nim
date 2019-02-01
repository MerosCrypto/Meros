include MainNetwork

#Open the channels.
fromMain.open()
toRPC.open()
toGUI.open()

proc mainRPC() {.raises: [
    AsyncError,
    SocketError
].} =
    {.gcsafe.}:
        #Create the RPC.
        rpc = newRPC(functions, addr toRPC, addr toGUI)

        try:
            #Start the RPC.
            asyncCheck rpc.start()
            #Start listening.
            asyncCheck rpc.listen(RPC_PORT)
        except:
            raise newException(AsyncError, "Couldn't start the RPC.")

proc mainGUI() {.raises: [ChannelError, WebViewError].} =
    when not defined(nogui):
        #Create the GUI.
        newGUI(addr fromMain, addr toRPC, addr toGUI, 800, 500)
