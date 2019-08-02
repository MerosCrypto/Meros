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
            "getMnemonic",
            proc () {.forceCheck: [].} =
                #Get the Mnemnoic.
                var mnemonic: JSONNode
                try:
                    mnemonic = gui.call("personal", "getMnemonic")
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)
                    return

                #Display the Mnemnoic.
                var js: string
                try:
                    js = &"""
                        document.getElementById("mnemonic").innerHTML = "{mnemonic.getStr()}";
                    """
                except ValueError as e:
                    gui.webview.error("Value Error", "Couldn't format the JS to display the Mnemonic: " & e.msg)
                    return
                if gui.webview.eval(js) != 0:
                    gui.webview.error("RPC Error", "Couldn't eval the JS to display the Mnemonic.")
                    return
        )

        #Create a Wallet from a Mnemonic.
        gui.webview.bindProc(
            "Personal",
            "setMnemonic",
            proc (
                mnemonic: string
            ) {.forceCheck: [].} =
                try:
                    discard gui.call("personal", "setMnemonic", mnemonic, "")
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)
                    return
        )

        #Create a Send.
        gui.webview.bindProc(
            "Personal",
            "send",
            proc (
                data: string
            ) {.forceCheck: [].} =
                #Create the Send.
                var hash: JSONNode
                try:
                    hash = gui.call("personal", "send", data.split("|")[0], data.split("|")[1])
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)
                    return

                #Display the hash.
                var js: string
                try:
                    js = &"""
                        document.getElementById("hash").innerHTML = "{hash.getStr()}";
                    """
                except ValueError as e:
                    gui.webview.error("Value Error", "Couldn't format the JS to display the hash: " & e.msg)
                    return
                if gui.webview.eval(js) != 0:
                    gui.webview.error("RPC Error", "Couldn't eval the JS to display the hash.")
                    return
        )
    except KeyError as e:
        doAssert(false, "Couldn't bind the GUI functions to WebView due to a KeyError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't bind the GUI functions to WebView due to a Exception: " & e.msg)
