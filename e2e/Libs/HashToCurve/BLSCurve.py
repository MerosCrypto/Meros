from typing import Tuple, List, Optional, Any

from ctypes import c_char_p, byref
from ctypes import Array, c_char, create_string_buffer

from e2e.Libs.Milagro.PrivateKeysAndSignatures import MilagroCurve, Big384, FP1Obj, G1Obj, G1_COFACTOR

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement
from e2e.Libs.HashToCurve.Weierstrass import WeierstrassCurve, mapToCurveSSWU3Mod4

def clone(
  value: FP1Obj
) -> FP1Obj:
  result: FP1Obj = FP1Obj()
  MilagroCurve.BIG_384_58_copy(result.g, value.g)
  result.XES = value.XES
  return result

class BLS12_381_F1(
  FieldElement
):
  value: FP1Obj

  #pylint: disable=super-init-not-called
  def __init__(
    self,
    value: Any = None
  ) -> None:
    if isinstance(value, List):
      if len(value) != 1:
        raise Exception("Incompatible field element integer list passed to BLS12_381_F1.")
      value = value[0]

    self.value = FP1Obj()
    if (value is None) or (isinstance(value, int) and (value == 0)):
      MilagroCurve.FP_BLS381_zero(byref(self.value))
    elif isinstance(value, int):
      if value == 1:
        MilagroCurve.FP_BLS381_one(byref(self.value))
      else:
        temp: Big384 = Big384()
        MilagroCurve.BIG_384_58_fromBytes(temp, c_char_p(value.to_bytes(48, byteorder="big")))
        MilagroCurve.FP_BLS381_rcopy(byref(self.value), temp)

    #Clone the value.
    elif isinstance(value, FP1Obj):
      self.value = clone(value)
    elif isinstance(value, BLS12_381_F1):
      self.value = clone(value.value)
    else:
      raise Exception("Unknown type passed to BLS12-381 F1 constructor.")

  def __add__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_add(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return BLS12_381_F1(result)

  def __sub__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_sub(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return BLS12_381_F1(result)

  def __mul__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_mul(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return BLS12_381_F1(result)

  def div(
    self,
    other: FieldElement,
    q: int
  ) -> Any:
    return self * (other ** (q - 2))

  def __pow__(
    self,
    exp: int
  ) -> Any:
    result: BLS12_381_F1 = BLS12_381_F1()
    MilagroCurve.FP_BLS381_pow(byref(result.value), byref(self.value), BLS12_381_F1(exp).value.toBig384())
    return result

  def __eq__(
    self,
    other: Any
  ) -> bool:
    return MilagroCurve.FP_BLS381_equals(byref(self.value), byref(other.value)) == 1

  def __ne__(
    self,
    other: Any
  ) -> bool:
    #pylint: disable=superfluous-parens
    return not (self == other)

  def sign(
    self
  ) -> int:
    neg: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_neg(byref(neg), byref(self.value))

    a: Big384 = self.value.toBig384()
    b: Big384 = neg.toBig384()
    #!= -1 because == 1 would cause 0 to identify as negative.
    return 0 if (MilagroCurve.BIG_384_58_comp(a, b) != -1) else 1

  def negative(
    self
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_neg(byref(result), byref(self.value))
    return BLS12_381_F1(result)

  def isSquare(
    self,
    q: FieldElement
  ) -> bool:
    squareCheck: FieldElement = self ** ((q - 1) // 2)
    return (squareCheck == BLS12_381_F1(0)) or (squareCheck == BLS12_381_F1(1))

  def sqrt(
    self
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_sqrt(byref(result), byref(self.value))
    return BLS12_381_F1(result)

  def serialize(
    self
  ) -> str:
    buffer: Array[c_char] = create_string_buffer(48)
    MilagroCurve.BIG_384_58_toBytes(buffer, self.value.toBig384())
    return bytes(buffer).hex()

class BLS12_381_G1(
  GroupElement
):
  value: G1Obj

  #pylint: disable=super-init-not-called
  def __init__(
    self,
    x: Any,
    y: Optional[BLS12_381_F1] = None
  ) -> None:
    self.value: G1Obj = G1Obj()
    if isinstance(x, G1Obj):
      MilagroCurve.ECP_BLS381_copy(byref(self.value), byref(x))
    elif isinstance(x, BLS12_381_G1):
      MilagroCurve.ECP_BLS381_copy(byref(self.value), byref(x.value))
    elif (isinstance(x, BLS12_381_F1) and isinstance(y, BLS12_381_F1)):
      xBig: Big384 = x.value.toBig384()
      yBig: Big384 = y.value.toBig384()
      if MilagroCurve.ECP_BLS381_set(byref(self.value), xBig, yBig) != 1:
        raise Exception("Passed invalid x/y to G1 constructor.")
    else:
      raise Exception("Unknown type passed to BLS12-381 G1 constructor.")

  def __add__(
    self,
    other: Any
  ) -> GroupElement:
    result: G1Obj = G1Obj()
    MilagroCurve.ECP_BLS381_copy(byref(result), byref(self.value))
    MilagroCurve.ECP_BLS381_add(byref(result), byref(other.value))
    return BLS12_381_G1(result)

  def clearCofactor(
    self
  ) -> GroupElement:
    result: BLS12_381_G1 = BLS12_381_G1(self.value)
    MilagroCurve.ECP_BLS381_mul(byref(result.value), G1_COFACTOR)
    return result

  @property
  def x(
    self
  ) -> str:
    return BLS12_381_F1(self.value.x).serialize()

  @property
  def y(
    self
  ) -> str:
    return BLS12_381_F1(self.value.y).serialize()

ISOGENY_CONSTANTS: List[List[BLS12_381_F1]] = [
  [
   BLS12_381_F1(0x11a05f2b1e833340b809101dd99815856b303e88a2d7005ff2627b56cdb4e2c85610c2d5f2e62d6eaeac1662734649b7),
   BLS12_381_F1(0x17294ed3e943ab2f0588bab22147a81c7c17e75b2f6a8417f565e33c70d1e86b4838f2a6f318c356e834eef1b3cb83bb),
   BLS12_381_F1(0xd54005db97678ec1d1048c5d10a9a1bce032473295983e56878e501ec68e25c958c3e3d2a09729fe0179f9dac9edcb0),
   BLS12_381_F1(0x1778e7166fcc6db74e0609d307e55412d7f5e4656a8dbf25f1b33289f1b330835336e25ce3107193c5b388641d9b6861),
   BLS12_381_F1(0xe99726a3199f4436642b4b3e4118e5499db995a1257fb3f086eeb65982fac18985a286f301e77c451154ce9ac8895d9),
   BLS12_381_F1(0x1630c3250d7313ff01d1201bf7a74ab5db3cb17dd952799b9ed3ab9097e68f90a0870d2dcae73d19cd13c1c66f652983),
   BLS12_381_F1(0xd6ed6553fe44d296a3726c38ae652bfb11586264f0f8ce19008e218f9c86b2a8da25128c1052ecaddd7f225a139ed84),
   BLS12_381_F1(0x17b81e7701abdbe2e8743884d1117e53356de5ab275b4db1a682c62ef0f2753339b7c8f8c8f475af9ccb5618e3f0c88e),
   BLS12_381_F1(0x80d3cf1f9a78fc47b90b33563be990dc43b756ce79f5574a2c596c928c5d1de4fa295f296b74e956d71986a8497e317),
   BLS12_381_F1(0x169b1f8e1bcfa7c42e0c37515d138f22dd2ecb803a0c5c99676314baf4bb1b7fa3190b2edc0327797f241067be390c9e),
   BLS12_381_F1(0x10321da079ce07e272d8ec09d2565b0dfa7dccdde6787f96d50af36003b14866f69b771f8c285decca67df3f1605fb7b),
   BLS12_381_F1(0x6e08c248e260e70bd1e962381edee3d31d79d7e22c837bc23c0bf1bc24c6b68c24b1b80b64d391fa9c8ba2e8ba2d229)
  ],
  [
   BLS12_381_F1(0x8ca8d548cff19ae18b2e62f4bd3fa6f01d5ef4ba35b48ba9c9588617fc8ac62b558d681be343df8993cf9fa40d21b1c),
   BLS12_381_F1(0x12561a5deb559c4348b4711298e536367041e8ca0cf0800c0126c2588c48bf5713daa8846cb026e9e5c8276ec82b3bff),
   BLS12_381_F1(0xb2962fe57a3225e8137e629bff2991f6f89416f5a718cd1fca64e00b11aceacd6a3d0967c94fedcfcc239ba5cb83e19),
   BLS12_381_F1(0x3425581a58ae2fec83aafef7c40eb545b08243f16b1655154cca8abc28d6fd04976d5243eecf5c4130de8938dc62cd8),
   BLS12_381_F1(0x13a8e162022914a80a6f1d5f43e7a07dffdfc759a12062bb8d6b44e833b306da9bd29ba81f35781d539d395b3532a21e),
   BLS12_381_F1(0xe7355f8e4e667b955390f7f0506c6e9395735e9ce9cad4d0a43bcef24b8982f7400d24bc4228f11c02df9a29f6304a5),
   BLS12_381_F1(0x772caacf16936190f3e0c63e0596721570f5799af53a1894e2e073062aede9cea73b3538f0de06cec2574496ee84a3a),
   BLS12_381_F1(0x14a7ac2a9d64a8b230b3f5b074cf01996e7f63c21bca68a81996e1cdf9822c580fa5b9489d11e2d311f7d99bbdcc5a5e),
   BLS12_381_F1(0xa10ecf6ada54f825e920b3dafc7a3cce07f8d1d7161366b74100da67f39883503826692abba43704776ec3a79a1d641),
   BLS12_381_F1(0x95fc13ab9e92ad4476d6e3eb3a56680f682b4ee96f7d03776df533978f31c1593174e4b4b7865002d6384d168ecdd0a),
   BLS12_381_F1(1)
  ],
  [
   BLS12_381_F1(0x90d97c81ba24ee0259d1f094980dcfa11ad138e48a869522b52af6c956543d3cd0c7aee9b3ba3c2be9845719707bb33),
   BLS12_381_F1(0x134996a104ee5811d51036d776fb46831223e96c254f383d0f906343eb67ad34d6c56711962fa8bfe097e75a2e41c696),
   BLS12_381_F1(0xcc786baa966e66f4a384c86a3b49942552e2d658a31ce2c344be4b91400da7d26d521628b00523b8dfe240c72de1f6),
   BLS12_381_F1(0x1f86376e8981c217898751ad8746757d42aa7b90eeb791c09e4a3ec03251cf9de405aba9ec61deca6355c77b0e5f4cb),
   BLS12_381_F1(0x8cc03fdefe0ff135caf4fe2a21529c4195536fbe3ce50b879833fd221351adc2ee7f8dc099040a841b6daecf2e8fedb),
   BLS12_381_F1(0x16603fca40634b6a2211e11db8f0a6a074a7d0d4afadb7bd76505c3d3ad5544e203f6326c95a807299b23ab13633a5f0),
   BLS12_381_F1(0x4ab0b9bcfac1bbcb2c977d027796b3ce75bb8ca2be184cb5231413c4d634f3747a87ac2460f415ec961f8855fe9d6f2),
   BLS12_381_F1(0x987c8d5333ab86fde9926bd2ca6c674170a05bfe3bdd81ffd038da6c26c842642f64550fedfe935a15e4ca31870fb29),
   BLS12_381_F1(0x9fc4018bd96684be88c9e221e4da1bb8f3abd16679dc26c1e8b6e6a1f20cabe69d65201c78607a360370e577bdba587),
   BLS12_381_F1(0xe1bba7a1186bdb5223abde7ada14a23c42a0ca7915af6fe06985e7ed1e4d43b9b3f7055dd4eba6f2bafaaebca731c30),
   BLS12_381_F1(0x19713e47937cd1be0dfd0b8f1d43fb93cd2fcbcb6caf493fd1183e416389e61031bf3a5cce3fbafce813711ad011c132),
   BLS12_381_F1(0x18b46a908f36f6deb918c143fed2edcc523559b8aaf0c2462e6bfe7f911f643249d9cdf41b44d606ce07c8a4d0074d8e),
   BLS12_381_F1(0xb182cac101b9399d155096004f53f447aa7b12a3426b08ec02710e807b4633f06c851c1919211f20d4c04f00b971ef8),
   BLS12_381_F1(0x245a394ad1eca9b72fc00ae7be315dc757b3b080d4c158013e6632d3c40659cc6cf90ad1c232a6442d9d3f5db980133),
   BLS12_381_F1(0x5c129645e44cf1102a159f748c4a3fc5e673d81d7e86568d9ab0f5d396a7ce46ba1049b6579afb7866b1e715475224b),
   BLS12_381_F1(0x15e6be4e990f03ce4ea50b3b42df2eb5cb181d8f84965a3957add4fa95af01b2b665027efec01c7704b456be69c8b604)
  ],
  [
   BLS12_381_F1(0x16112c4c3a9c98b252181140fad0eae9601a6de578980be6eec3232b5be72e7a07f3688ef60c206d01479253b03663c1),
   BLS12_381_F1(0x1962d75c2381201e1a0cbd6c43c348b885c84ff731c4d59ca4a10356f453e01f78a4260763529e3532f6102c2e49a03d),
   BLS12_381_F1(0x58df3306640da276faaae7d6e8eb15778c4855551ae7f310c35a5dd279cd2eca6757cd636f96f891e2538b53dbf67f2),
   BLS12_381_F1(0x16b7d288798e5395f20d23bf89edb4d1d115c5dbddbcd30e123da489e726af41727364f2c28297ada8d26d98445f5416),
   BLS12_381_F1(0xbe0e079545f43e4b00cc912f8228ddcc6d19c9f0f69bbb0542eda0fc9dec916a20b15dc0fd2ededda39142311a5001d),
   BLS12_381_F1(0x8d9e5297186db2d9fb266eaac783182b70152c65550d881c5ecd87b6f0f5a6449f38db9dfa9cce202c6477faaf9b7ac),
   BLS12_381_F1(0x166007c08a99db2fc3ba8734ace9824b5eecfdfa8d0cf8ef5dd365bc400a0051d5fa9c01a58b1fb93d1a1399126a775c),
   BLS12_381_F1(0x16a3ef08be3ea7ea03bcddfabba6ff6ee5a4375efa1f4fd7feb34fd206357132b920f5b00801dee460ee415a15812ed9),
   BLS12_381_F1(0x1866c8ed336c61231a1be54fd1d74cc4f9fb0ce4c6af5920abc5750c4bf39b4852cfe2f7bb9248836b233d9d55535d4a),
   BLS12_381_F1(0x167a55cda70a6e1cea820597d94a84903216f763e13d87bb5308592e7ea7d4fbc7385ea3d529b35e346ef48bb8913f55),
   BLS12_381_F1(0x4d2f259eea405bd48f010a01ad2911d9c6dd039bb61a6290e591b36e636a5c871a5c29f4f83060400f8b49cba8f6aa8),
   BLS12_381_F1(0xaccbb67481d033ff5852c1e48c50c477f94ff8aefce42d28c0f9a88cea7913516f968986f7ebbea9684b529e2561092),
   BLS12_381_F1(0xad6b9514c767fe3c3613144b45f1496543346d98adf02267d5ceef9a00d9b8693000763e3b90ac11e99b138573345cc),
   BLS12_381_F1(0x2660400eb2e4f3b628bdd0d53cd76f2bf565b94e72927c1cb748df27942480e420517bd8714cc80d1fadc1326ed06f7),
   BLS12_381_F1(0xe0fa1d816ddc03e6b24255e0d7819c171c40f65e273b853324efcd6356caa205ca2f570f13497804415473a1d634b8f),
   BLS12_381_F1(1)
  ]
]

#This should be generic, and therefore applicable to any curve.
#That said, after spending as long as I have on this, since Meros only needs the BLS curve
#I really don't want to guarantee that this isogeny map will always be valid.
#It's likely further parameterized. Hence why it's in this file and type-locked.
#-- Kayaba
def isogenyMap(
  #SSWU returns a FE.
  x: FieldElement,
  y: FieldElement,
  q: int
) -> Tuple[BLS12_381_F1, BLS12_381_F1]:
  def innerMap(
    #Allows us to use a FE as a F1.
    z: Any,
    constants: List[BLS12_381_F1]
  ) -> BLS12_381_F1:
    result: BLS12_381_F1 = BLS12_381_F1(0)
    for i, k in enumerate(constants):
      result = result + (k * (z ** i))
    return result

  xNum: BLS12_381_F1 = innerMap(x, ISOGENY_CONSTANTS[0])
  xDen: BLS12_381_F1 = innerMap(x, ISOGENY_CONSTANTS[1])
  yNum: BLS12_381_F1 = innerMap(x, ISOGENY_CONSTANTS[2])
  yDen: BLS12_381_F1 = innerMap(x, ISOGENY_CONSTANTS[3])

  return (xNum.div(xDen, q), (y * yNum).div(yDen, q))

#pylint: disable=too-few-public-methods
class BLS12381G1Curve(
  WeierstrassCurve
):
  def __init__(
    self
  ) -> None:
    WeierstrassCurve.__init__(
      self,
      BLS12_381_F1,
      BLS12_381_G1,
      False,
      0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab,
      1,
      0,
      4,
      0x144698a3b8e9433d693a02c96d4982b0ea985383ee66a8d8e8981aefd881ac98936f8da0e0f97f5cf428082d584c1d,
      0x12e2908d11688030018b12e8753eee3b2016c1f0f24f4070a0b9c14fcef35ef55a23215a316ceaa5d1cc48e98e172be0,
      11
    )

  def mapToCurve(
    self,
    u: BLS12_381_F1
  ) -> BLS12_381_G1:
    return BLS12_381_G1(*isogenyMap(*mapToCurveSSWU3Mod4(self, u), self.q))
