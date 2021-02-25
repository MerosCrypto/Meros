from typing import Dict, Optional, Any

class Response:
  status_code: int

  def json(
    self
  ) -> Dict[str, Any]:
    ...

def post(
  url: str,
  json: Optional[Dict[str, Any]] = ...,
  headers: Optional[Dict[str, str]] = ...
) -> Response:
  ...
