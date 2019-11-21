"""
#Tests proper handling of Verifications with unsynced Transactions which are parsable yet have invalid signatures.
#Meros used to allow any Verifications of any Transaction, no matter its data or signature.
#Meros no longer allows this. All Verifications must be of Transactions on the DAG.

#Types.
from typing import Dict, IO, Any

#Transaction classes.
from PythonTests.Classes.Transactions.Data import Data
from PythonTests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Meros import MessageType

#JSON standard lib.
import json

#The following PyLint error is due to our custom message rules.
#pylint: disable=too-many-statements
def VParsableTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Parsable.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Blockchain.
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
    )
    consensus.add(SignedVerification.fromJSON(vectors["verification"]))
    #Transactions.
    transactions: Transactions = Transactions()
    transactions.add(Data.fromJSON(vectors["data"]))

    #Handshake with the node.
    rpc.meros.connect(254, 254, self.blockchain.blocks[3].hash)

    sentLast: bool = False
    reqHash: bytes = bytes()
    msg: bytes = bytes()
    height: int = 0
    while True:
        try:
            msg = rpc.meros.recv()
        except TestError as e:
            if (not sentLast) or (str(e) != "Node disconnected us as a peer."):
                raise e
            break

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.syncingAcknowledged()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.last())
            else:
                if height >= len(blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            reqHash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == reqHash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            reqHash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == reqHash:
                    rpc.meros.blockBody(block)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.ElementRequest:
            holder: bytes = msg[1 : 49]

            rpc.meros.element(
                consensus.holders[holder][int.from_bytes(msg[49 : 53], "big")]
            )

        elif MessageType(msg[0]) == MessageType.TransactionRequest:
            sentLast = True
            rpc.meros.transaction(transactions.txs[msg[1 : 49]])

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            pass

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())
"""
