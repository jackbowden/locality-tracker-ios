import sys
import socketserver
import http.server

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

port = 8000
server = ThreadedHTTPServer(('0.0.0.0', 8000), http.server.SimpleHTTPRequestHandler)
try:
    server.serve_forever
except KeyboardInterrupt:
    pass