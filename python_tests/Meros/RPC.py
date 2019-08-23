#Types.
from typing import Dict, List, Any

#Meros class.
from python_tests.Meros.Meros import Meros

#NodeError Exception.
from python_tests.Tests.Errors import NodeError

#JSON standard lib.
import json

#Socket standard lib.
import socket

#RPC class.
class RPC:
    #Constructor.
    def __init__(
        self,
        meros: Meros
    ) -> None:
        self.meros: Meros = meros
        self.socket: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect(("127.0.0.1", meros.rpc))

    #Call an RPC method.
    def call(
        self,
        module: str,
        method: str,
        args: List[Any] = []
    ) -> Any:
        #Send the call.
        self.socket.send(
            bytes(
                json.dumps(
                    {
                        "jsonrpc": "2.0",
                        "id": 0,
                        "method": module + "_" + method,
                        "params": args
                    }
                ),
                "utf-8"
            )
        )

        #Get the result.
        response: bytes = bytes()
        next: bytes = bytes()
        counter: int = 0
        while True:
            try:
                next = self.socket.recv(1)
            except Exception:
                raise NodeError()
            if len(next) == 0:
                raise NodeError()
            response += next

            if response[-1] == response[0]:
                counter += 1
            elif (chr(response[-1]) == ']') and (chr(response[0]) == '['):
                counter -= 1
            elif (chr(response[-1]) == '}') and (chr(response[0]) == '{'):
                counter -= 1
            if counter == 0:
                break

        #Raise an exception on error.
        result: Dict[str, Any] = json.loads(response)
        if "error" in result:
            raise Exception(result["error"]["message"])
        return result["result"]

    #Quit Meros.
    def quit(
        self
    ) -> None:
        self.call(
            "system",
            "quit"
        )
