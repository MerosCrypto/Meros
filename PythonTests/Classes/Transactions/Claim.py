#Types.
from typing import Dict, List, Tuple, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, Signature

#Transaction classs.
from PythonTests.Classes.Transactions.Transaction import Transaction

#Blake2b standard function.
from hashlib import blake2b

#Claim class.
class Claim(Transaction):
    #Constructor.
    def __init__(
        self,
        inputs: List[Tuple[bytes, int]],
        output: bytes,
        signature: bytes = Signature().serialize()
    ) -> None:
        self.inputs: List[Tuple[bytes, int]] = inputs
        self.output: bytes = output
        self.amount: int = 0

        self.signature: bytes = signature
        self.hash = blake2b(b'\1' + self.signature, digest_size=32).digest()

    #Transaction -> Claim. Satisifes static typing requirements.
    @staticmethod
    def fromTransaction(
        tx: Transaction
    ) -> Any:
        return tx

    #Sign.
    def sign(
        self,
        privKeys: List[PrivateKey]
    ) -> None:
        signatures: List[Signature] = [
            privKeys[0].sign(
                b'\1' +
                self.inputs[0][0] +
                self.inputs[0][1].to_bytes(1, "big") +
                self.output
            )
        ]

        for i in range(1, len(self.inputs)):
            signatures.append(
                privKeys[i].sign(
                    b'\1' +
                    self.inputs[i][0] +
                    self.inputs[i][1].to_bytes(1, "big") +
                    self.output
                )
            )

        self.signature = Signature.aggregate(signatures).serialize()
        self.hash = blake2b(b'\1' + self.signature, digest_size=32).digest()

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result: bytes = len(self.inputs).to_bytes(1, "big")
        for txInput in self.inputs:
            result += txInput[0] + txInput[1].to_bytes(1, "big")
        result += self.output + self.signature
        return result

    #Claim -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "descendant": "Claim",
            "inputs": [],
            "outputs": [{
                "key": self.output.hex().upper(),
                "amount": str(self.amount)
            }],

            "signature": self.signature.hex().upper(),
            "hash": self.hash.hex().upper()
        }
        for txInput in self.inputs:
            result["inputs"].append({
                "hash": txInput[0].hex().upper(),
                "nonce": txInput[1]
            })
        return result

    #JSON -> Claim.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        inputs: List[Tuple[bytes, int]] = []
        for txInput in json["inputs"]:
            inputs.append((bytes.fromhex(txInput["hash"]), txInput["nonce"]))

        result: Claim = Claim(
            inputs,
            bytes.fromhex(json["outputs"][0]["key"]),
            bytes.fromhex(json["signature"])
        )
        result.amount = int(json["outputs"][0]["amount"])
        return result
