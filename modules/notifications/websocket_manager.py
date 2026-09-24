import json
from typing import Any, List, Dict, Optional
from fastapi import WebSocket


def parse_auth_frame(raw: Any) -> Optional[str]:
    """Returns the JWT from an auth frame `{"type": "auth", "token": "<jwt>"}`, or None if malformed."""
    if not isinstance(raw, str):
        return None
    try:
        message = json.loads(raw)
    except ValueError:
        return None
    if not isinstance(message, dict) or message.get("type") != "auth":
        return None
    token = message.get("token")
    if not isinstance(token, str) or not token.strip():
        return None
    return token.strip()


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def accept(self, websocket: WebSocket) -> None:
        """Accepts the handshake only. The socket receives no broadcasts until register() is called."""
        await websocket.accept()

    def register(self, websocket: WebSocket) -> None:
        """Adds an authenticated socket to the broadcast list."""
        if websocket not in self.active_connections:
            self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: Dict):
        payload = json.dumps(message)
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(payload)
            except Exception:
                disconnected.append(connection)
        
        for conn in disconnected:
            self.disconnect(conn)


websocket_manager = ConnectionManager()
