#Hash master type.
type Hash*[bits: static[int]] = object
  data*: array[bits div 8, uint8]
