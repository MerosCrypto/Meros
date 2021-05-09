#pylint: disable=invalid-name,unused-argument,no-self-use

class mpz:
  def __init__(
    self,
    x: int
  ) -> None:
    ...

  def __int__(
    self
  ) -> int:
    ...

  def __add__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __sub__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __rsub__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __mul__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __pow__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __floordiv__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __mod__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __and__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __or__(
    self,
    x: 'mpz'
  ) -> 'mpz':
    ...

  def __lshift__(
    self,
    x: int
  ) -> 'mpz':
    ...

def powmod(
  b: mpz,
  e: mpz,
  mod: mpz
) -> mpz:
  ...

def to_binary(
  x: mpz
) -> bytes:
  ...

def from_binary(
  x: bytes
) -> mpz:
  ...
