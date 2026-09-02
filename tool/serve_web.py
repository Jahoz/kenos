#!/usr/bin/env python3
"""KENOS dev static server — std-lib only.

`python3 -m http.server` sends no cache headers, so browsers keep a
heuristic cache of main.dart.js across rebuilds. build/web is rewired
by every deploy (prod credentials) and every dev-local build (local
stack): a stale tab once ran the CLOUD build while the local server
held the seeded galaxy — an evening of "where is my data?". Every
response here carries Cache-Control: no-store: a reload always runs
the build that is on disk.

Usage: python3 tool/serve_web.py [port]   (default 4308)
"""

import http.server
import os
import socketserver
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4308
    web_dir = os.path.join(os.path.dirname(__file__), '..', 'build', 'web')
    os.chdir(web_dir)
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(('', port), NoCacheHandler) as httpd:
        print(f'serving {os.getcwd()} on :{port} (Cache-Control: no-store)')
        httpd.serve_forever()


if __name__ == '__main__':
    main()
