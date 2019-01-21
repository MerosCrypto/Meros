#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#GUI object.
import ../objects/GUIObj

#WebView lib.
import mc_webview

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Get the nonce to use with new transactions.
proc getNonce*(gui: GUI): string {.raises: [ChannelError].} =
    #Create a var for the address.
    var address: string
    try:
        #Ask for the Wallet info.
        gui.toRPC[].send(%* {
            "module": "personal",
            "method": "getWallet",
            "args": []
        })
        #Get the wallet info.
        address = gui.toGUI[].recv()["address"].getStr()
    except:
        raise newException(ChannelError, "Couldn't send wallet.get/get the Wallet info via the channel.")

    try:
        #Ask for the Wallet's height.
        gui.toRPC[].send(%* {
            "module": "lattice",
            "method": "getHeight",
            "args": [
                address
            ]
        })
        #Set the result to the Wallet's height (AKA the next nonce).
        result = gui.toGUI[].recv()["height"].getStr()
    except:
        raise newException(ChannelError, "Couldn't send lattice.getHeight/get the height via the channel.")

#Add the Wallet bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [WebViewError].} =
    try:
        #Get the Wallet.
        gui.webview.bindProcNoArg(
            "Personal",
            "getWallet",
            proc () {.raises: [KeyError, ChannelError, WebViewError].} =
                #Var for the response.
                var wallet: JSONNode
                try:
                    gui.toRPC[].send(%* {
                        "module": "personal",
                        "method": "getWallet",
                        "args": []
                    })

                    #Receive the Wallet info.
                    wallet = gui.toGUI[].recv()
                except:
                    raise newException(ChannelError, "Couldn't get the Wallet.")

                #Set the elements.
                if gui.webview.eval(
                    "document.getElementById('seed').innerHTML = '" & wallet["seed"].getStr() & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
                if gui.webview.eval(
                    "document.getElementById('publicKey').innerHTML = '" & wallet["publicKey"].getStr() & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
                if gui.webview.eval(
                    "document.getElementById('address').innerHTML = '" & wallet["address"].getStr() & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
        )

        #Create a Wallet from a Seed.
        gui.webview.bindProc(
            "Personal",
            "setSeed",
            proc (seed: string) {.raises: [ChannelError].} =
                #Var for the response.
                var res: JSONNode
                try:
                    gui.toRPC[].send(%* {
                        "module": "personal",
                        "method": "setSeed",
                        "args": [
                            seed
                        ]
                    })

                    #Receive whether or not it worked.
                    res = gui.toGUI[].recv()
                except:
                    raise newException(ChannelError, "Couldn't set the Wallet's Seed.")
        )

        #Send.
        gui.webview.bindProc(
            "Personal",
            "send",
            proc (dataArg: string) {.raises: [ChannelError, WebViewError].} =
                #Split the data up.
                var data: seq[string] = dataArg.split(" ")

                #Var for the response.
                var hash: string
                try:
                    #Create the Send.
                    gui.toRPC[].send(%* {
                        "module": "personal",
                        "method": "send",
                        "args": [
                            data[0],
                            data[1],
                            gui.getNonce()
                        ]
                    })
                    
                    hash = gui.toGUI[].recv()["hash"].getStr()
                except:
                    raise newException(ChannelError, "Couldn't send personal.send over the channel.")

                #Receive the hash and print it.
                if gui.webview.eval(
                    "document.getElementById('hash').innerHTML = '" & hash & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
        )

        #Receive.
        gui.webview.bindProc(
            "Personal",
            "receive",
            proc (dataArg: string) {.raises: [ChannelError, WebViewError].} =
                #Split the data.
                var data: seq[string] = dataArg.split(" ")

                #Var for the response.
                var hash: string
                try:
                    #Create the Receive.
                    gui.toRPC[].send(%* {
                        "module": "personal",
                        "method": "receive",
                        "args": [
                            data[0],
                            data[1],
                            gui.getNonce()
                        ]
                    })
                    
                    hash = gui.toGUI[].recv()["hash"].getStr()
                except:
                    raise newException(ChannelError, "Couldn't send personal.receive over the channel.")

                #Receive the hash and print it.
                if gui.webview.eval(
                    "document.getElementById('hash').innerHTML = '" & hash & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
        )
    except:
        raise newException(WebViewError, "Couldn't bind procs to WebView.")
