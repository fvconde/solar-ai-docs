"""unittest offline: transporte ficticio e HTTP real somente em loopback."""

import contextlib
import http.client
import io
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time
import unittest
import urllib.parse
from email.message import Message
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

import eco


TOKEN = "TOKEN_FICTICIO.PAYLOAD_FICTICIO.ASSINATURA_FICTICIA"
PRIVATE = {"Authorization": "Bearer CLIENTE_FICTICIO",
           "X-Serverless-Authorization": "Bearer CLIENTE_SERVERLESS_FICTICIO",
           "Cookie": "sessao=COOKIE_FICTICIO", "X-Outro": "VALOR_FICTICIO_OCULTO"}


def message(values=None):
    headers = Message()
    for name, value in (values or {}).items():
        headers[name] = value
    return headers


def internal_observation():
    return eco.observe("192.0.2.20", message({"X-Forwarded-For": "192.0.2.10",
                                            "X-Forwarded-Proto": "https"}))


class FakeTransport:
    def __init__(self):
        self.calls = []
        self.token = TOKEN.encode("ascii")
        self.metadata_headers = {"Metadata-Flavor": "Google"}
        self.internal = json.dumps(internal_observation()).encode("utf-8")
        self.fail_at = 0

    def get(self, url, headers, timeout, limit):
        self.calls.append((url, dict(headers), timeout, limit))
        if len(self.calls) == self.fail_at:
            raise OSError("ERRO_FICTICIO " + TOKEN)
        if len(self.calls) == 1:
            return self.token, self.metadata_headers
        return self.internal, {}


@contextlib.contextmanager
def running(diagnostic):
    server = eco.Server(("127.0.0.1", 0), diagnostic)
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.02})
    thread.start()
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def request(server, path="/", headers=None, method="GET", body=None):
    connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
    try:
        connection.request(method, path, body=body, headers=headers or {})
        response = connection.getresponse()
        return response.status, response.read(), dict(response.getheaders())
    finally:
        connection.close()


class FixtureHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        self.server.calls.append((self.path, dict(self.headers)))
        if self.path.startswith("/metadata?"):
            body = TOKEN.encode("ascii")
            flavor = "Google"
        elif self.path == "/interno":
            body = json.dumps(eco.observe(self.client_address[0], self.headers)).encode("ascii")
            flavor = None
        elif self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/nao-alcancar")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        elif self.path == "/grande":
            body, flavor = b"x" * 100, None
        elif self.path == "/sem-tamanho":
            body, flavor = b"x" * 100, None
        elif self.path == "/lento":
            time.sleep(0.2)
            body, flavor = b"{}", None
        else:
            body, flavor = b"{}", None
        self.send_response(200)
        if self.path != "/sem-tamanho":
            self.send_header("Content-Length", str(len(body)))
        if flavor:
            self.send_header("Metadata-Flavor", flavor)
        self.end_headers()
        try:
            self.wfile.write(body)
        except OSError:
            pass


@contextlib.contextmanager
def fixture():
    server = ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
    server.calls = []
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.02})
    thread.start()
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


class LocalTransport(eco.Transport):
    """Mapeamento exclusivamente de teste; nunca acessa os hosts reais."""

    def __init__(self, server):
        super().__init__()
        self.server = server

    def get(self, url, headers, timeout, limit):
        if url.startswith(eco.METADATA_URL + "?"):
            path = "/metadata?" + urllib.parse.urlsplit(url).query
        elif url == "https://interno.test/":
            path = "/interno"
        else:
            raise AssertionError("Destino inesperado no teste offline.")
        local = "http://127.0.0.1:" + str(self.server.server_port) + path
        return super().get(local, headers, timeout, limit)


class EcoTests(unittest.TestCase):
    def test_defaults_and_environment(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(eco.Config.from_environment(), eco.Config())
        with patch.dict(os.environ, {"PORT": "18480", "DIAG_MODE": "encadear",
                                     "DIAG_INTERNAL_URL": "https://Interno.Test:443/"}, clear=True):
            config = eco.Config.from_environment()
            self.assertEqual((config.port, config.internal_url), (18480, "https://interno.test"))

    def test_invalid_configuration(self):
        for values in ({"PORT": "0"}, {"PORT": "65536"}, {"PORT": "-1"},
                       {"PORT": " 8080"}, {"DIAG_MODE": "outro"}, {"DIAG_MODE": "encadear"},
                       {"DIAG_INTERNAL_URL": "https://interno.test"}):
            with self.subTest(values=values), patch.dict(os.environ, values, clear=True):
                with self.assertRaises(ValueError):
                    eco.Config.from_environment()

    def test_malicious_origins_rejected(self):
        urls = ("http://interno.test", "https://u:senha@interno.test", "https://interno.test/path",
                "https://interno.test/?destino=outro", "https://interno.test#fragmento",
                "https://interno.test:8443", "https://127.0.0.1", "https://[::1]",
                "https://localhost", "https://metadata.google.internal", "https://interno.test/../",
                "https://interno.test\\outro", "https://interno.test%2foutro", "https://interno.test./",
                "https://interno..test", "https://-interno.test", "https://2130706433",
                "https://127.1", "https://0x7f000001", "https://interno.test\n",
                "https://" + "a" * 64 + ".test")
        for url in urls:
            with self.subTest(url=url), self.assertRaises(ValueError):
                eco.Config("encadear", url)

    def test_echo_redacts_all_other_values_and_preserves_duplicates(self):
        headers = message(PRIVATE)
        headers["X-Forwarded-For"] = "192.0.2.1"
        headers["X-Forwarded-For"] = "198.51.100.2"
        headers["Forwarded"] = 'for=192.0.2.1;proto=https'
        headers["X-Forwarded-Proto"] = "https"
        transport = FakeTransport()
        status, data = eco.Diagnostic(eco.Config(), transport).respond("127.0.0.1", headers)
        self.assertEqual(status, 200)
        self.assertEqual(set(data), eco.OBSERVATION_KEYS)
        self.assertEqual(data["X-Forwarded-For"], ["192.0.2.1", "198.51.100.2"])
        self.assertIn("x-serverless-authorization", data["nomesHeaders"])
        for value in PRIVATE.values():
            self.assertNotIn(value, json.dumps(data))
        self.assertEqual(transport.calls, [])

    def test_chain_audience_metadata_and_only_diagnostic_forwarding(self):
        headers = message({**PRIVATE, "X-Forwarded-For": "198.51.100.2, 192.0.2.1",
                           "Forwarded": 'for=192.0.2.1;proto=https', "X-Forwarded-Proto": "https"})
        transport = FakeTransport()
        status, data = eco.Diagnostic(eco.Config("encadear", "https://Interno.Test:443/"), transport).respond("127.0.0.1", headers)
        self.assertEqual(status, 200)
        self.assertEqual(set(data), {"borda", "interno"})
        first, second = transport.calls
        self.assertEqual(urllib.parse.urlsplit(first[0]).netloc, "metadata.google.internal")
        self.assertEqual(first[0].split("?")[0], eco.METADATA_URL)
        self.assertEqual(urllib.parse.parse_qs(urllib.parse.urlsplit(first[0]).query),
                         {"audience": ["https://interno.test"], "format": ["full"]})
        self.assertEqual(first[1], {"Metadata-Flavor": "Google"})
        self.assertEqual(second[0], "https://interno.test/")
        self.assertEqual(set(second[1]), {*eco.DIAGNOSTIC_HEADERS, "X-Serverless-Authorization"})
        self.assertEqual(second[1]["X-Serverless-Authorization"], "Bearer " + TOKEN)
        self.assertEqual(second[1]["X-Forwarded-For"], "198.51.100.2, 192.0.2.1")
        self.assertEqual(first[2:], (eco.REQUEST_TIMEOUT, eco.TOKEN_LIMIT))
        self.assertEqual(second[2:], (eco.UPSTREAM_TIMEOUT, eco.RESPONSE_LIMIT))
        self.assertNotIn(TOKEN, json.dumps(data))

    def test_metadata_and_internal_failures_are_quiet(self):
        for fail_at in (1, 2):
            transport = FakeTransport()
            transport.fail_at = fail_at
            stdout, stderr = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                status, data = eco.Diagnostic(eco.Config("encadear", "https://interno.test"), transport).respond("127.0.0.1", message(PRIVATE))
            self.assertEqual(status, 502)
            self.assertIsNone(data["interno"])
            self.assertNotIn(TOKEN, json.dumps(data))
            self.assertNotIn("ERRO_FICTICIO", json.dumps(data))
            self.assertEqual((stdout.getvalue(), stderr.getvalue()), ("", ""))

    def test_invalid_metadata_never_reaches_internal(self):
        for raw, flavor in ((b"TOKEN_INVALIDO", "Google"), (TOKEN.encode(), "outro"),
                            (b"", "Google"), (b"\xff", "Google")):
            transport = FakeTransport()
            transport.token = raw
            transport.metadata_headers = {"Metadata-Flavor": flavor}
            status, _ = eco.Diagnostic(eco.Config("encadear", "https://interno.test"), transport).respond("127.0.0.1", message())
            self.assertEqual(status, 502)
            self.assertEqual(len(transport.calls), 1)

    def test_internal_schema_and_token_leak_are_rejected(self):
        base = internal_observation()
        variants = [b"HTML_ERRO_FICTICIO", b"[]", b"\xff",
                    json.dumps({**base, "Authorization": TOKEN}).encode(),
                    json.dumps({**base, "peerTCP": "nao-ip"}).encode(),
                    json.dumps({**base, "Forwarded": [TOKEN]}).encode(),
                    json.dumps({**base, "nomesHeaders": ["Cookie: VALOR_FICTICIO"]}).encode(),
                    json.dumps({**base, "X-Forwarded-For": "tipo-invalido"}).encode()]
        for raw in variants:
            transport = FakeTransport()
            transport.internal = raw
            status, data = eco.Diagnostic(eco.Config("encadear", "https://interno.test"), transport).respond("127.0.0.1", message())
            self.assertEqual(status, 502)
            self.assertIsNone(data["interno"])

    def test_direct_value_limits(self):
        for value in ("x" * (eco.DIAGNOSTIC_VALUE_LIMIT + 1), "a\r\nb"):
            with self.assertRaises(ValueError):
                eco.observe("127.0.0.1", message({"X-Forwarded-For": value}))

    def test_http_echo_and_errors_emit_zero_logs(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            with running(eco.Diagnostic(eco.Config())) as server:
                status, raw, response_headers = request(server, headers=PRIVATE)
                self.assertEqual(status, 200)
                self.assertEqual(response_headers["Cache-Control"], "no-store")
                data = json.loads(raw)
                self.assertEqual(data["peerTCP"], "127.0.0.1")
                for value in PRIVATE.values():
                    self.assertNotIn(value.encode(), raw)
                for path, method, body, expected in (("/?url=https://outro.test", "GET", None, 404),
                                                     ("/", "POST", None, 405), ("/", "GET", "corpo", 400)):
                    status, raw, _ = request(server, path, method=method, body=body)
                    self.assertEqual((status, raw), (expected, b"{}"))
        self.assertEqual((stdout.getvalue(), stderr.getvalue()), ("", ""))

    def test_real_loopback_http_chain(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr), fixture() as upstream:
            with running(eco.Diagnostic(eco.Config("encadear", "https://interno.test"), LocalTransport(upstream))) as server:
                status, raw, _ = request(server, headers={**PRIVATE, "X-Forwarded-For": "192.0.2.10",
                                                         "Forwarded": 'for=192.0.2.10', "X-Forwarded-Proto": "https"})
                self.assertEqual(status, 200)
                data = json.loads(raw)
                self.assertEqual(data["interno"]["X-Forwarded-For"], ["192.0.2.10"])
                self.assertEqual(len(upstream.calls), 2)
                received = {key.lower(): value for key, value in upstream.calls[1][1].items()}
                self.assertNotIn("authorization", received)
                self.assertNotIn("cookie", received)
                self.assertNotIn("x-outro", received)
                self.assertEqual(received["x-serverless-authorization"], "Bearer " + TOKEN)
                self.assertNotIn(TOKEN.encode(), raw)
        self.assertEqual((stdout.getvalue(), stderr.getvalue()), ("", ""))

    def test_no_redirect_or_oversized_body_with_real_http(self):
        with fixture() as upstream:
            transport = eco.Transport()
            base = "http://127.0.0.1:" + str(upstream.server_port)
            for path in ("/redirect", "/grande", "/sem-tamanho"):
                with self.assertRaises(Exception):
                    transport.get(base + path, {}, 2, 32)
            self.assertEqual([path for path, _ in upstream.calls], ["/redirect", "/grande", "/sem-tamanho"])

    def test_native_timeout_is_enforced(self):
        with fixture() as upstream:
            with self.assertRaises((TimeoutError, OSError)):
                eco.Transport().get("http://127.0.0.1:" + str(upstream.server_port) + "/lento", {}, 0.05, 32)

    def test_concurrency_limit_closes_without_diagnostic_or_logs(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            with running(eco.Diagnostic(eco.Config())) as server:
                for _ in range(8):
                    self.assertTrue(server.slots.acquire(blocking=False))
                try:
                    with socket.create_connection(server.server_address, timeout=3) as client:
                        self.assertEqual(client.recv(1024), b"")
                finally:
                    for _ in range(8):
                        server.slots.release()
        self.assertEqual((stdout.getvalue(), stderr.getvalue()), ("", ""))

    def test_header_total_budget(self):
        reader = eco.HeaderReader(io.BytesIO((b"X-Nome: " + b"x" * 1000 + b"\r\n") * 20))
        with self.assertRaises(http.client.HTTPException):
            for _ in range(20):
                reader.readline()

    def test_raw_http_bounds_and_malformed_requests_quiet(self):
        requests = [b"GET / HTTP/1.1\r\nX-Longo: " + b"x" * 4096 + b"\r\n\r\n",
                    b"GET / HTTP/1.1\r\n" + b"X-Nome: x\r\n" * 65 + b"\r\n",
                    b"GET /" + b"x" * 2048 + b" HTTP/1.1\r\n\r\n",
                    b"INVALIDO\r\n\r\n", b"GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"]
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            with running(eco.Diagnostic(eco.Config())) as server:
                for raw in requests:
                    with socket.create_connection(server.server_address, timeout=3) as client:
                        client.sendall(raw)
                        data = client.recv(32768)
                        self.assertNotIn(b"200 OK", data)
                with socket.create_connection(server.server_address, timeout=3) as client:
                    client.sendall(b"GET / HTTP/1.1\r\n")
                server.handle_error(None, None)
        self.assertEqual((stdout.getvalue(), stderr.getvalue()), ("", ""))

    def test_startup_failure_silent_subprocess(self):
        env = {"PORT": "0", "DIAG_MODE": "encadear", "DIAG_INTERNAL_URL": "http://PROIBIDO"}
        if "SystemRoot" in os.environ:
            env["SystemRoot"] = os.environ["SystemRoot"]
        result = subprocess.run([sys.executable, "-B", str(Path(eco.__file__).resolve())],
                                env=env, capture_output=True, timeout=5)
        self.assertEqual((result.returncode, result.stdout, result.stderr), (1, b"", b""))

    def test_server_and_handler_exceptions_silent(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            with patch.object(eco, "Server", side_effect=OSError("ERRO_FICTICIO " + TOKEN)):
                self.assertEqual(eco.main(), 1)
            with running(eco.Diagnostic(eco.Config())) as server:
                with patch.object(server.diagnostic, "respond", side_effect=ValueError("ERRO_FICTICIO " + TOKEN)):
                    status, raw, _ = request(server)
                    self.assertEqual((status, raw), (400, b"{}"))
        self.assertEqual((stdout.getvalue(), stderr.getvalue()), ("", ""))

    def test_proxy_environment_disabled(self):
        with patch.dict(os.environ, {"http_proxy": "http://PROXY_FICTICIO.test",
                                     "https_proxy": "http://PROXY_FICTICIO.test"}):
            transport = eco.Transport()
            self.assertFalse(any(isinstance(handler, eco.urllib.request.ProxyHandler)
                                 and handler.proxies for handler in transport.opener.handlers))

    def test_dockerfile_copies_only_runtime_and_nonroot(self):
        text = Path(eco.__file__).with_name("Dockerfile").read_text(encoding="utf-8")
        copies = [line for line in text.splitlines() if line.startswith("COPY ")]
        self.assertEqual(copies, ["COPY eco.py /app/eco.py"])
        self.assertIn("USER 65532:65532", text)


if __name__ == "__main__":
    unittest.main()
