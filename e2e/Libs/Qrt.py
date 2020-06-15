from typing import List

origin: List[int] = [
  0x19c9369f278adc02,
  0x84b2b22ab2383ee4,
  0x84b2b22ab2383ee6,
  0x9d7b84b495b3e3f6,
  0x84b2b22ab2383ee2,
  0x37c470b49213f790,
  0x9d7b84b495b3e3fe,
  0x1000a0105137c,
  0x84b2b22ab2383ef2,
  0x368e964a8edce1fc,
  0x37c470b49213f7b0,
  0x19c9368e278fdf4c,
  0x9d7b84b495b3e3be,
  0x2e4da23cbc7d4570,
  0x1000a010513fc,
  0x84f35772bac24232,
  0x84b2b22ab2383ff2,
  0x37c570ba9314e4fc,
  0x368e964a8edce3fc,
  0xb377c390213cdb0e,
  0x37c470b49213f3b0,
  0x85ed5a3aa99c24f2,
  0x19c9368e278fd74c,
  0xaabff0000780000e,
  0x9d7b84b495b3f3be,
  0x84b6b3dab03038f2,
  0x2e4da23cbc7d6570,
  0x511ea03494ffc,
  0x1000a010553fc,
  0xae0c0220343c6c0e,
  0x84f35772bac2c232,
  0x800000008000000e,
  0x84b2b22ab2393ff2,
  0xb376c29c202bc97e,
  0x37c570ba9316e4fc,
  0x9c3062488879e6ce,
  0x368e964a8ed8e3fc,
  0x41e42c08e47e70,
  0xb377c3902134db0e,
  0x85b9b108a60f56ce,
  0x37c470b49203f3b0,
  0x19dd3b6e21f3cb4c,
  0x85ed5a3aa9bc24f2,
  0x198ddf682c428ac0,
  0x19c9368e27cfd74c,
  0x4b7c68431ca84b0,
  0xaabff0000700000e,
  0x8040655489ffefbe,
  0x9d7b84b494b3f3be,
  0x18c1354e32bfa74c,
  0x84b6b3dab23038f2,
  0xaaf613cc0f74627e,
  0x2e4da23cb87d6570,
  0x3248b3d6b3342a8c,
  0x511ea0b494ffc,
  0xb60813c00e70700e,
  0x1000a110553fc,
  0x1e0d022a05393ffc,
  0xae0c0220143c6c0e,
  0xe0c0220143c6c00,
  0x84f35772fac2c232,
  0xc041e55948fbfdce,
  0x800000000000000e,
  0
]

def generateQrtElement(
  base: List[int],
  n: int
) -> int:
  result: int = 0
  while n != 0:
    if (n & 1) == 1:
      result = result ^ base[0]
    n = n >> 1
    del base[0]
  return result

def generateQrtTable(
  base: List[int]
) -> List[int]:
  result: List[int] = []
  i: int = 0
  while i < (1 << len(base)):
    result.append(generateQrtElement(base, i))
    i += 1
  return result

tables: List[List[int]] = []
for t in range(11):
  subset: List[int] = []
  elems: int = 6
  if t > 8:
    elems = 5
  for _ in range(elems):
    subset.append(origin[0])
    del subset[0]
  tables.append(generateQrtTable(subset))

def qrt(
  value: int
) -> int:
  bitMask6: int = 0b111111
  bitMask5: int = 0b11111

  result: int = 0
  for e in range(9):
    result = result ^ tables[e][(value >> (e * 6)) & bitMask6]
  result = result ^ tables[9][(value >> 54) & bitMask5]
  result = result ^ tables[10][(value >> 59) & bitMask5]
  return result
