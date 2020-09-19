from typing import Optional, List, Any
from abc import ABC, abstractmethod

class FieldElement(
  ABC
):
  @property
  def value(
    self
  ) -> List[int]:
    ...

  @value.setter
  @abstractmethod
  def value(
    self,
    value: List[int]
  ):
    ...

  @abstractmethod
  def __init__(
    self,
    value: Optional[Any] = None
  ) -> None:
    ...

  #Other should be another FieldElement or a value passable to init.
  @abstractmethod
  def __add__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def __mul__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def __div__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def __pow__(
    self,
    exp: int
  ) -> Any:
    ...

  @abstractmethod
  def __eq__(
    self,
    other: Any
  ) -> Any:
    ...

  #Positive/negative (0/1); not the signature scheme operation.
  @abstractmethod
  def sign(
    self
  ) -> int:
    ...

  @abstractmethod
  def negative(
    self
  ) -> Any:
    ...

class GroupElement(
  ABC
):
  @abstractmethod
  def __add__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def __mul__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def clearCofactor(
    self
  ) -> Any:
    ...
