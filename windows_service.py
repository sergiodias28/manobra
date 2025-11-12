# -*- coding: utf-8 -*-
import os
import sys
import socket
import win32serviceutil
import win32service
import win32event
import servicemanager
from waitress import serve

# Ensure workspace root is on path
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

# Import Flask app
from server.app import app  # noqa: E402


class ManobraFlaskService(win32serviceutil.ServiceFramework):
    _svc_name_ = "ManobraFlaskService"
    _svc_display_name_ = "Manobra API Service"
    _svc_description_ = "Serviço Flask que expõe a API de manobra para execução SSH."

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
        socket.setdefaulttimeout(60)

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.hWaitStop)
        try:
            # Best-effort terminate; waitress doesn't expose graceful shutdown easily here
            os._exit(0)
        except Exception:
            pass

    def SvcDoRun(self):
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_, ""),
        )
        self.main()

    def main(self):
        port = int(os.environ.get("PORT", "5000"))
        host = os.environ.get("HOST", "0.0.0.0")
        # Serve WSGI app with Waitress
        serve(app, host=host, port=port)


if __name__ == "__main__":
    win32serviceutil.HandleCommandLine(ManobraFlaskService)
