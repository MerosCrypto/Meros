#Types.
from typing import Dict, List, Any

#Transaction classs.
from python_tests.Classes.Transactions.Transaction import Transaction

#BLS lib.
import blspy

#Blake2b standard function.
from hashlib import blake2b

#Claim class.
class Claim(Transaction):
    #Constructor.
    def __init__(
        self,
        inputs: List[bytes],
        output: bytes,
        signature: bytes = bytes(96)
    ) -> None:
        self.inputs: List[bytes] = inputs
        self.output: bytes = output
        self.amount: int = 0

        self.signature: bytes = signature
        self.hash = blake2b(b'\1' + self.signature, digest_size = 48).digest()

        self.verified: bool = False

    #Transaction -> Claim. Satisifes static typing requirements.
    @staticmethod
    def fromTransaction(
        tx: Transaction
    ) -> Any:
        return tx

    #Sign.
    def sign(
        self,
        privKeys: List[blspy.PrivateKey]
    ) -> None:
        signatures: List[blspy.Signature] = [
            privKeys[0].sign(b'\1' + self.inputs[0] + self.output)
        ]

        for i in range(1, len(self.inputs)):
            signatures.append(privKeys[i].sign(b'\1' + self.inputs[i] + self.output))

        self.signature = blspy.Signature.aggregate(signatures).serialize()
        self.hash = blake2b(b'\1' + self.signature, digest_size = 48).digest()

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result: bytes = len(self.inputs).to_bytes(1, byteorder = "big")
        for input in self.inputs:
            result += input
        result += (
            self.output +
            self.signature
        )
        return result

    #Claim -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        if self.amount == 0:
            raise Exception("Python tests didn't set this Claim's value.")

        result: Dict[str, Any] = {
            "descendant": "Claim",
            "inputs": [],
            "outputs": [{
                "key": self.output.hex().upper(),
                "amount": str(self.amount)
            }],

            "signature": self.signature.hex().upper(),
            "hash": self.hash.hex().upper(),

            "verified": self.verified
        }
        for input in self.inputs:
            result["inputs"].append({
                "hash": input.hex().upper()
            })
        return result

    #JSON -> Claim.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        inputs: List[bytes] = []
        for input in json["inputs"]:
            inputs.append(bytes.fromhex(input["hash"]))

        result: Claim = Claim(
            inputs,
            bytes.fromhex(json["outputs"][0]["key"]),
            bytes.fromhex(json["signature"])
        )
        result.amount = int(json["outputs"][0]["amount"])
        if json["verified"]:
            result.verified = True
        return result
