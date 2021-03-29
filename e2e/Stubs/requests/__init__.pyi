from typing import Iterator, Dict, List, Optional, Union, Any

class Response:
  status_code: int

  def json(
    self
  ) -> Dict[str, Any]:
    ...

def post(
  url: str,
  data: Optional[Union[Iterator[bytes], str]] = ...,
  json: Optional[Union[List[Dict[str, Any]], Dict[str, Any]]] = ...,
  headers: Optional[Dict[str, str]] = ...
) -> Response:
  ...
