"""Diagnostico temporario S-26; stdlib, sem logs ou persistencia.

PORT=8080; DIAG_MODE=eco (padrao) ou encadear.
DIAG_INTERNAL_URL: origem HTTPS do interno, somente no modo encadear.
Configuracao vem do operador; nenhuma URL e aceita da requisicao.
"""

import http.client
import ipaddress
import json
import os
import re
import socket
import sys
import threading
import urllib.parse
import urllib.request
import urllib.error
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


METADATA_URL = (
    "http://metadata.google.internal/computeMetadata/v1/instance/"
    "service-accounts/default/identity"
)
DIAGNOSTIC_HEADERS = ("X-Forwarded-For", "Forwarded", "X-Forwarded-Proto")
OBSERVATION_KEYS = frozenset(("peerTCP", "nomesHeaders", *DIAGNOSTIC_HEADERS))
HEADER_BUDGET = 16384
HEADER_LINE_LIMIT = 4096
HEADER_COUNT_LIMIT = 64
DIAGNOSTIC_VALUE_LIMIT = 4096
RESPONSE_LIMIT = 16384
TOKEN_LIMIT = 8192
REQUEST_TIMEOUT = 3
UPSTREAM_TIMEOUT = 5
TOKEN_PATTERN = re.compile(r"[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\Z")
HEADER_NAME_PATTERN = re.compile(r"[!#$%&'*+.^_`|~0-9A-Za-z-]{1,256}\Z")


def canonical_origin(value):
    """Aceita somente uma origem HTTPS DNS, porta padrao, sem userinfo."""
    if not isinstance(value, str) or not re.fullmatch(
        r"https://[a-zA-Z0-9.-]+(?::443)?/?", value
    ):
        raise ValueError("Configuracao invalida.")
    parsed = urllib.parse.urlsplit(value)
    host = parsed.hostname
    if not host or len(host) > 253 or host.endswith("."):
        raise ValueError("Configuracao invalida.")
    if "." not in host or not re.fullmatch(r"[a-z]{2,63}", host.rsplit(".", 1)[-1]):
        raise ValueError("Configuracao invalida.")
    for label in host.split("."):
        if not re.fullmatch(r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?", label):
            raise ValueError("Configuracao invalida.")
    try:
        ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        raise ValueError("Configuracao invalida.")
    if host == "localhost" or host.endswith((".localhost", ".internal", ".local")):
        raise ValueError("Configuracao invalida.")
    return "https://" + host.lower()


@dataclass(frozen=True)
class Config:
    mode: str = "eco"
    internal_url: str = ""
    port: int = 8080

    def __post_init__(self):
        if self.mode not in ("eco", "encadear") or not 1 <= self.port <= 65535:
            raise ValueError("Configuracao invalida.")
        if self.mode == "encadear":
            object.__setattr__(self, "internal_url", canonical_origin(self.internal_url))
        elif self.internal_url:
            raise ValueError("Configuracao invalida.")

    @classmethod
    def from_environment(cls):
        port = os.environ.get("PORT", "8080")
        if not re.fullmatch(r"[0-9]{1,5}", port):
            raise ValueError("Configuracao invalida.")
        return cls(os.environ.get("DIAG_MODE", "eco"),
                   os.environ.get("DIAG_INTERNAL_URL", ""), int(port))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Transport:
    """GET limitado; TLS padrao, sem proxies de ambiente nem redirecionamento."""

    def __init__(self):
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), NoRedirect()
        )

    def get(self, url, headers, timeout, limit):
        request = urllib.request.Request(url, headers=headers, method="GET")
        try:
            response = self.opener.open(request, timeout=timeout)
        except urllib.error.HTTPError as failure:
            failure.close()
            raise ValueError("Resposta invalida.") from None
        with response:
            if response.status != 200:
                raise ValueError("Resposta invalida.")
            declared = response.headers.get("Content-Length")
            if declared is not None and (not declared.isdecimal() or int(declared) > limit):
                raise ValueError("Resposta invalida.")
            body = response.read(limit + 1)
            if len(body) > limit:
                raise ValueError("Resposta invalida.")
            return body, response.headers


def observe(peer, headers):
    # Valores de headers fora desta lista nunca sao lidos para a resposta.
    observation = {"peerTCP": peer}
    for name in DIAGNOSTIC_HEADERS:
        values = headers.get_all(name, [])
        if len(values) > 16 or sum(len(v) for v in values) > DIAGNOSTIC_VALUE_LIMIT:
            raise ValueError("Entrada invalida.")
        if any("\r" in v or "\n" in v for v in values):
            raise ValueError("Entrada invalida.")
        observation[name] = values
    allowed = {name.lower() for name in DIAGNOSTIC_HEADERS}
    names = sorted({name.lower() for name in headers.keys() if name.lower() not in allowed})
    if len(names) > HEADER_COUNT_LIMIT or any(not HEADER_NAME_PATTERN.fullmatch(n) for n in names):
        raise ValueError("Entrada invalida.")
    observation["nomesHeaders"] = names
    return observation


def validate_internal(body, token):
    # Nao devolver JSON arbitrario, corpo de erro ou campos extras do upstream.
    text = body.decode("utf-8", errors="strict")
    if token in text:
        raise ValueError("Resposta invalida.")
    data = json.loads(text)
    if not isinstance(data, dict) or set(data) != OBSERVATION_KEYS:
        raise ValueError("Resposta invalida.")
    if not isinstance(data["peerTCP"], str):
        raise ValueError("Resposta invalida.")
    ipaddress.ip_address(data["peerTCP"])
    for name in DIAGNOSTIC_HEADERS:
        values = data[name]
        if (not isinstance(values, list) or len(values) > 16
                or any(not isinstance(v, str) or "\r" in v or "\n" in v for v in values)
                or sum(len(v) for v in values) > DIAGNOSTIC_VALUE_LIMIT):
            raise ValueError("Resposta invalida.")
    names = data["nomesHeaders"]
    if (not isinstance(names, list) or len(names) > HEADER_COUNT_LIMIT
            or any(not isinstance(n, str) or not HEADER_NAME_PATTERN.fullmatch(n) for n in names)):
        raise ValueError("Resposta invalida.")
    return data


class Diagnostic:
    def __init__(self, config, transport=None):
        self.config = config
        self.transport = transport if transport is not None else Transport()

    def respond(self, peer, headers):
        observation = observe(peer, headers)
        if self.config.mode == "eco":
            return 200, observation
        token = None
        raw = None
        outgoing = None
        try:
            query = urllib.parse.urlencode({"audience": self.config.internal_url, "format": "full"})
            raw, metadata_headers = self.transport.get(
                METADATA_URL + "?" + query, {"Metadata-Flavor": "Google"}, REQUEST_TIMEOUT, TOKEN_LIMIT
            )
            if metadata_headers.get("Metadata-Flavor") != "Google":
                raise ValueError("Resposta invalida.")
            token = raw.decode("ascii", errors="strict").strip()
            if not TOKEN_PATTERN.fullmatch(token):
                raise ValueError("Resposta invalida.")
            raw = None
            outgoing = {"X-Serverless-Authorization": "Bearer " + token}
            for name in DIAGNOSTIC_HEADERS:
                if observation[name]:
                    outgoing[name] = ", ".join(observation[name])
            raw, _ = self.transport.get(
                self.config.internal_url + "/", outgoing, UPSTREAM_TIMEOUT, RESPONSE_LIMIT
            )
            internal = validate_internal(raw, token)
            return 200, {"borda": observation, "interno": internal}
        except Exception:
            return 502, {"borda": observation, "interno": None}
        finally:
            # Strings gerenciadas nao permitem zeragem garantida. Nao ha cache.
            if outgoing is not None:
                outgoing.clear()
            token = None
            raw = None


class HeaderReader:
    def __init__(self, source):
        self.source = source
        self.total = 0

    def readline(self, size=-1):
        limit = HEADER_LINE_LIMIT + 1 if size < 0 else min(size, HEADER_LINE_LIMIT + 1)
        line = self.source.readline(limit)
        self.total += len(line)
        if len(line) > HEADER_LINE_LIMIT or self.total > HEADER_BUDGET:
            raise http.client.HTTPException("Entrada invalida.")
        return line


class Handler(BaseHTTPRequestHandler):
    # Uma requisicao por conexao; nenhuma linha de log, corpo ou excecao.
    protocol_version = "HTTP/1.0"
    server_version = ""
    sys_version = ""

    def setup(self):
        self.request.settimeout(REQUEST_TIMEOUT)
        super().setup()

    def log_message(self, *args):
        pass

    def log_error(self, *args):
        pass

    def send_error(self, code, message=None, explain=None):
        self.reply(code, {})

    def parse_request(self):
        source = self.rfile
        self.rfile = HeaderReader(source)
        try:
            result = super().parse_request()
        finally:
            self.rfile = source
        self.close_connection = True
        if result and len(self.headers) > HEADER_COUNT_LIMIT:
            self.send_error(431)
            return False
        return result

    def handle_one_request(self):
        try:
            self.raw_requestline = self.rfile.readline(2049)
            if not self.raw_requestline:
                self.close_connection = True
                return
            if len(self.raw_requestline) > 2048:
                self.requestline = ""
                self.request_version = "HTTP/1.0"
                self.command = ""
                self.send_error(414)
                return
            if not self.parse_request():
                return
            if self.command != "GET":
                self.send_error(405)
            elif self.path != "/":
                self.send_error(404)
            elif self.headers.get("Transfer-Encoding") or self.headers.get("Content-Length", "0") != "0":
                self.send_error(400)
            else:
                status, data = self.server.diagnostic.respond(self.client_address[0], self.headers)
                self.reply(status, data)
            self.wfile.flush()
        except (socket.timeout, OSError):
            self.close_connection = True
        except Exception:
            self.close_connection = True
            self.reply(400, {})

    def reply(self, status, data):
        try:
            body = json.dumps(data, ensure_ascii=True, separators=(",", ":")).encode("ascii")
            if len(body) > RESPONSE_LIMIT:
                status, body = 502, b"{}"
            self.send_response_only(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)
        except Exception:
            self.close_connection = True


class Server(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 8

    def __init__(self, address, diagnostic):
        self.diagnostic = diagnostic
        self.slots = threading.BoundedSemaphore(8)
        super().__init__(address, Handler)

    def handle_error(self, request, client_address):
        pass

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            self.shutdown_request(request)

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()


def main():
    try:
        config = Config.from_environment()
        with Server(("0.0.0.0", config.port), Diagnostic(config)) as server:
            server.serve_forever()
        return 0
    except (Exception, KeyboardInterrupt):
        return 1


if __name__ == "__main__":
    sys.exit(main())
