"""Exercise real STUN UDP packets against an isolated shadNet process."""
import os
from pathlib import Path
import socket
import shutil
import struct
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent

def free_port(kind):
    with socket.socket(socket.AF_INET, kind) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]

def exercise(binary, expect_modern):
    tcp, web, udp = free_port(socket.SOCK_STREAM), free_port(socket.SOCK_STREAM), free_port(socket.SOCK_DGRAM)
    runtime = Path(binary).resolve().parent
    env = os.environ.copy()
    env['PATH'] = str(runtime) + os.pathsep + r'C:\msys64\ucrt64\bin' + os.pathsep + env['PATH']
    env['QT_PLUGIN_PATH'] = str(runtime)
    with tempfile.TemporaryDirectory(prefix='udp-wire-') as directory:
        work = Path(directory)
        shutil.copy2(binary, work / 'shadnet.exe')
        (work / 'shadnet.cfg').write_text(
            f'[General]\nHost=127.0.0.1\nUnsecuredPort={tcp}\nMatching2Enabled=true\n'
            f'MatchingUdpPort={udp}\nWebApiPort={web}\nStatsEnabled=false\n'
            'RegistrationSecretKey=local-diagnostic-only\n')
        for name in ['worlds.cfg', 'scoreboards.cfg']:
            (work / name).write_bytes((runtime / name).read_bytes())
        with (work / 'server.log').open('w') as output:
            proc = subprocess.Popen([str(work / 'shadnet.exe')], cwd=work, env=env, stdout=output,
                                    stderr=output, creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                for _ in range(50):
                    try:
                        with socket.create_connection(('127.0.0.1', tcp), timeout=.1):
                            break
                    except OSError:
                        if proc.poll() is not None:
                            raise RuntimeError((work / 'server.log').read_text())
                        time.sleep(.1)
                else:
                    raise RuntimeError('isolated server did not start: ' + (work / 'server.log').read_text())
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                    client.bind(('127.0.0.1', 0))
                    client.settimeout(.5)
                    ping = b'\x01' + b'wire-test'.ljust(16, b'\0') + socket.inet_aton('127.0.0.1')
                    for header, expected in [(b'\xff'*4, True), (b'\xff\x83'+b'\xff'*4, expect_modern)]:
                        client.sendto(header + ping, ('127.0.0.1', udp))
                        try:
                            reply, _ = client.recvfrom(1024)
                        except socket.timeout:
                            assert not expected, 'valid STUN frame was not answered'
                            continue
                        assert expected, 'baseline unexpectedly supports modern framing'
                        assert reply == header + socket.inet_aton('127.0.0.1') + struct.pack('!H', client.getsockname()[1])
                    for bad in [b'\xff\x83\xff', b'\xff\x84'+b'\xff'*4+ping,
                                b'\xff\x83\x00\x01\xff\xff'+ping]:
                        client.sendto(bad, ('127.0.0.1', udp))
                        try:
                            client.recvfrom(1024)
                        except socket.timeout:
                            continue
                        raise AssertionError('malformed/non-signaling packet accepted')
                print('PASS:', binary.name, 'modern supported:', expect_modern,
                      'legacy preserved; reply address/port verified; invalid packets rejected')
            finally:
                proc.terminate()
                proc.wait(timeout=5)

if __name__ == '__main__':
    exercise(Path(sys.argv[1]), sys.argv[2] == 'modern')
