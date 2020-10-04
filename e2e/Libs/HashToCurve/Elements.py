from typing import Any
from abc import ABC, abstractmethod

class FieldElement(
  ABC
):
  @abstractmethod
  def __init__(
    self,
    #List[int] or int. The BLS impl shipped in this codebase also accepts itself.
    #Just a nice convenience function to cleanly make sure args are viable.
    value: Any
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
    other: int
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
  ) -> bool:
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
  def clearCofactor(
    self
  ) -> Any:
    ...
