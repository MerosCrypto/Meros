# pyright: strict

#Subprocess class.
from subprocess import Popen

class Meros:
    #Constructor.
    def __init__(
        self,
        db: str,
        tcp: int,
        rpc: int
    ) -> None:
        #Save the config.
        self.db: str = db
        self.tcp: int = tcp
        self.rpc: int = rpc

        #Create the instance.
        self.process: Popen = Popen(["./build/Meros", "--db", db, "--tcpPort", str(tcp), "--rpcPort", str(rpc)])

    #Quit.
    def quit(
        self
    ) -> None:
        while self.process.poll() == None:
            pass
        if self.process.returncode != 0:
            raise Exception("Meros didn't quit with code 0.")
