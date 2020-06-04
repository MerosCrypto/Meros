type Hash*[bits: static[int]] = object
  data*: array[bits div 8, byte]
