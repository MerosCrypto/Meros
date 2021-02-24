from typing import Dict, Optional, Any

class Response:
  def json(
    self
  ) -> Dict[str, Any]:
    ...

def post(
  url: str,
  json: Optional[Dict[str, Any]] = ...
) -> Response:
  ...
