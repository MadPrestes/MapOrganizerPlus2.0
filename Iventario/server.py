from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import json
import mimetypes
from pathlib import Path
import ssl


ROOT = Path(__file__).resolve().parent
WEB_ROOT = ROOT / "web"
API_METHODS = {"hostgroup.get", "host.get"}


class InventoryHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/config":
            try:
                config = self.load_config()
                zabbix = config["Zabbix"]
                endpoint = zabbix.get("Url", "").strip()
                parsed = urlparse(endpoint)
                hostname = parsed.hostname or ""
                if ":" in hostname and not hostname.startswith("["):
                    hostname = f"[{hostname}]"
                port = f":{parsed.port}" if parsed.port else ""
                safe_url = f"{parsed.scheme}://{hostname}{port}{parsed.path}"
                self.send_json(200, {
                    "configured": bool(endpoint and zabbix.get("Token", "").strip()),
                    "url": safe_url,
                    "ignoreCert": bool(zabbix.get("ignoreCert", False)),
                })
            except (OSError, ValueError, KeyError, TypeError) as error:
                self.send_json(200, {"configured": False, "error": str(error)})
            return

        if self.path not in ("/", "/index.html"):
            self.send_error(404)
            return

        page = WEB_ROOT / "index.html"
        content = page.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def do_POST(self):
        if self.path != "/api/zabbix":
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 1_000_000:
                raise ValueError("Corpo da solicitação inválido.")
            payload = json.loads(self.rfile.read(length))
            result = self.call_zabbix(payload)
            self.send_json(200, {"result": result})
        except (ValueError, KeyError, TypeError) as error:
            self.send_json(400, {"error": str(error)})
        except (HTTPError, URLError, TimeoutError) as error:
            detail = getattr(error, "reason", None) or str(error)
            self.send_json(502, {"error": f"Não foi possível consultar o Zabbix: {detail}"})
        except Exception as error:
            self.send_json(502, {"error": f"Falha na comunicação com o Zabbix: {error}"})

    def load_config(self):
        with (ROOT / "Config.local.json").open("r", encoding="utf-8") as config_file:
            config = json.load(config_file)
        if not isinstance(config, dict) or not isinstance(config.get("Zabbix"), dict):
            raise ValueError("Config.local.json precisa conter a seção Zabbix.")
        return config

    def call_zabbix(self, payload):
        config = self.load_config()["Zabbix"]
        endpoint = config.get("Url", "").strip()
        token = config.get("Token", "").strip()
        method = payload.get("method")
        params = payload.get("params", {})

        if method not in API_METHODS:
            raise ValueError("Método da API não permitido.")
        if not token:
            raise ValueError("Informe um token de API do Zabbix.")
        if not isinstance(params, dict):
            raise ValueError("Parâmetros inválidos.")

        parsed = urlparse(endpoint)
        if parsed.scheme not in ("http", "https") or not parsed.netloc or parsed.username:
            raise ValueError("Informe a URL HTTP/HTTPS da API do Zabbix.")
        if not parsed.path.endswith("/api_jsonrpc.php"):
            endpoint = endpoint.rstrip("/") + "/api_jsonrpc.php"

        request_body = json.dumps({
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1,
        }).encode("utf-8")
        request = Request(
            endpoint,
            data=request_body,
            headers={
                "Content-Type": "application/json-rpc",
                "Authorization": f"Bearer {token}",
            },
            method="POST",
        )

        context = ssl._create_unverified_context() if config.get("ignoreCert", False) else None
        with urlopen(request, timeout=60, context=context) as response:
            result = json.loads(response.read().decode("utf-8"))

        if "error" in result:
            message = result["error"].get("data") or result["error"].get("message") or "Erro da API"
            raise ValueError(f"Erro do Zabbix: {message}")
        return result.get("result", [])

    def send_json(self, status, data):
        content = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def log_message(self, format_string, *args):
        print(f"[{self.log_date_time_string()}] {format_string % args}")


if __name__ == "__main__":
    mimetypes.add_type("text/html", ".html")
    address = ("127.0.0.1", 8765)
    server = ThreadingHTTPServer(address, InventoryHandler)
    print(f"Inventário Zabbix disponível em http://{address[0]}:{address[1]}")
    print("Pressione Ctrl+C para encerrar.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor encerrado.")
        server.server_close()