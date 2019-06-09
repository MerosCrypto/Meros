#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#GUI object.
import ../objects/GUIObj

#String utils and string format standard libs.
import strutils
import strformat

#JSON standard lib.
import json

#Add the Wallet bindings to the GUI.
proc addTo*(
    gui: GUI
) {.forceCheck: [].} =
    try:
        #Get the Wallet.
        gui.webview.bindProcNoArg(
            "Personal",
            "getWallet",
            proc () {.forceCheck: [].} =
                #Receive the Wallet info.
                var wallet: JSONNode
                try:
                    wallet = gui.call("personal", "getWallet")
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)

                #Display the Wallet info.
                var js: string
                try:
                    js = &"""
                        document.getElementById("privateKey").innerHTML = "{wallet["privateKey"].getStr()}";
                        document.getElementById("publicKey").innerHTML = "{wallet["publicKey"].getStr()}";
                        document.getElementById("address").innerHTML = "{wallet["address"].getStr()}";
                    """
                except ValueError as e:
                    gui.webview.error("Value Error", "Couldn't format the JS to display the wallet info: " & e.msg)
                if gui.webview.eval(js) != 0:
                    gui.webview.error("RPC Error", "Couldn't eval the JS to display the Wallet.")
        )

        #Create a Wallet from a secret.
        gui.webview.bindProc(
            "Personal",
            "setSecret",
            proc (
                secret: string
            ) {.forceCheck: [].} =
                try:
                    discard gui.call("personal", "setSecret", secret)
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)
        )

        #Send.
        gui.webview.bindProc(
            "Personal",
            "send",
            proc (
                dataArg: string
            ) {.forceCheck: [].} =
                #Split the data up.
                var data: seq[string] = dataArg.split(" ")
                if data.len != 2:
                    gui.webview.error("GUI Error", "Personal.send was handed the wrong amount of arguments.")
                    return

                #Get the nonce.
                var nonce: int = gui.getNonce()
                if nonce == -1:
                    return

                #Create the Send and grab the hash.
                var hash: string
                try:
                    hash = gui.call(
                        "personal",
                        "send",
                        data[0],
                        data[1],
                        nonce
                    )["hash"].getStr()
                except KeyError as e:
                    gui.webview.error("Key Error", "gui.call didn't throw an RPCError but doesn't have a hash field: " & e.msg)
                    return
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)
                    return

                #Display the hash.
                var js: string
                try:
                    js = &"""
                        document.getElementById("hash").innerHTML = "{hash}";
                    """
                except ValueError as e:
                    gui.webview.error("Value Error", "Couldn't format the JS to display the Send's hash: " & e.msg)
                    return

                if gui.webview.eval(js) != 0:
                    gui.webview.error("RPC Error", "Couldn't eval the JS to display the Send's hash.")
                    return
        )

        #Receive.
        gui.webview.bindProc(
            "Personal",
            "receive",
            proc (
                dataArg: string
            ) {.forceCheck: [].} =
                #Split the data.
                var data: seq[string] = dataArg.split(" ")
                if data.len != 2:
                    gui.webview.error("GUI Error", "Personal.receive was handed the wrong amount of arguments.")
                    return

                #Get the nonce.
                var nonce: int = gui.getNonce()
                if nonce == -1:
                    return

                #Create the Receive and grab the hash.
                var hash: string
                try:
                    hash = gui.call(
                        "personal",
                        "receive",
                        data[0],
                        data[1],
                        nonce
                    )["hash"].getStr()
                except KeyError as e:
                    gui.webview.error("Key Error", "gui.call didn't throw an RPCError but doesn't have a hash field: " & e.msg)
                    return
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)
                    return

                #Display the hash.
                var js: string
                try:
                    js = &"""
                        document.getElementById("hash").innerHTML = "{hash}";
                    """
                except ValueError as e:
                    gui.webview.error("Value Error", "Couldn't fromat the JS to display the Receive's hash: " & e.msg)
                    return

                if gui.webview.eval(js) != 0:
                    gui.webview.error("RPC Error", "Couldn't eval the JS to display the Receive's hash.")
                    return
        )
    except KeyError as e:
        doAssert(false, "Couldn't bind the GUI functions to WebView due to a KeyError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't bind the GUI functions to WebView due to a Exception: " & e.msg)
