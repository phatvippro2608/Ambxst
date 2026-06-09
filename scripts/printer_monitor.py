#!/usr/bin/env python3
import time
import sys
import json
import subprocess
import re
import socket

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        return res.stdout
    except Exception:
        return ""

def check_cups_active():
    try:
        res = subprocess.run(["lpstat", "-r"], capture_output=True, text=True, timeout=2)
        return "scheduler is running" in res.stdout
    except Exception:
        return False

def get_printer_options(printer_name):
    options = []
    output = run_cmd(["lpoptions", "-p", printer_name, "-l"])
    for line in output.splitlines():
        line = line.strip()
        if not line or '/' not in line or ':' not in line:
            continue
        try:
            parts = line.split(':', 1)
            name_label = parts[0].split('/', 1)
            opt_name = name_label[0].strip()
            opt_label = name_label[1].strip() if len(name_label) > 1 else opt_name
            
            choices_str = parts[1].strip()
            choices = []
            current = None
            for choice in choices_str.split():
                if choice.startswith('*'):
                    choice_val = choice[1:]
                    current = choice_val
                    choices.append(choice_val)
                else:
                    choices.append(choice)
            
            if choices:
                options.append({
                    "name": opt_name,
                    "label": opt_label,
                    "current": current,
                    "choices": choices
                })
        except Exception:
            continue
    return options

def get_printer_status():
    if not check_cups_active():
        return {"cups_active": False, "printers": [], "jobs": [], "completed_jobs": []}

    # Get accepting requests map
    accepting_output = run_cmd(["lpstat", "-a"])
    accepting_map = {}
    for line in accepting_output.splitlines():
        if "accepting requests" in line:
            parts = line.split(" accepting requests ")
            if len(parts) == 2:
                accepting_map[parts[0].strip()] = True
        elif "not accepting requests" in line:
            parts = line.split(" not accepting requests ")
            if len(parts) == 2:
                accepting_map[parts[0].strip()] = False

    # Get device URIs map
    devices_output = run_cmd(["lpstat", "-v"])
    devices_map = {}
    for line in devices_output.splitlines():
        if line.startswith("device for "):
            parts = line[len("device for "):].split(": ")
            if len(parts) >= 2:
                devices_map[parts[0].strip()] = parts[1].strip()

    # Get default printer
    default_output = run_cmd(["lpstat", "-d"])
    default_printer = ""
    for line in default_output.splitlines():
        if "system default destination: " in line:
            default_printer = line.split("system default destination: ")[1].strip()
            break

    # Get printer status
    status_output = run_cmd(["lpstat", "-p"])
    printers = []
    for line in status_output.splitlines():
        if line.startswith("printer "):
            name = ""
            status = "unknown"
            # Match "printer <name> is <status>."
            m = re.match(r"printer\s+(\S+)\s+is\s+([^.]+)\.", line)
            if m:
                name = m.group(1)
                status = m.group(2)
            else:
                m2 = re.match(r"printer\s+(\S+)\s+(\S+)", line)
                if m2:
                    name = m2.group(1)
                    status = m2.group(2)
            
            if name:
                printers.append({
                    "name": name,
                    "status": status.strip(),
                    "device": devices_map.get(name, ""),
                    "accepting": accepting_map.get(name, False),
                    "is_default": (name == default_printer),
                    "options": get_printer_options(name)
                })

    # Get active jobs
    jobs_output = run_cmd(["lpstat", "-o"])
    jobs = []
    for line in jobs_output.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            job_id = parts[0]
            user = parts[1]
            size = parts[2]
            date_str = " ".join(parts[3:])
            
            printer = ""
            if "-" in job_id:
                printer = job_id.rsplit("-", 1)[0]
            
            jobs.append({
                "id": job_id,
                "printer": printer,
                "user": user,
                "size": size,
                "date": date_str,
                "status": "pending",
                "file": "(unknown)"
            })

    # Enhance active jobs status and file name with lpq
    for job in jobs:
        lpq_out = run_cmd(["lpq", "-P", job["printer"]])
        job_num = job["id"].split("-")[-1]
        for line in lpq_out.splitlines():
            tokens = line.split()
            if len(tokens) >= 5 and tokens[2] == job_num:
                # Rank Owner Job File(s) Total Size
                # e.g.: active dev 245 myfile.pdf 1024 bytes
                job["file"] = " ".join(tokens[3:-2])
                if tokens[0] == "active":
                    job["status"] = "processing"
                break

    # Get completed jobs (last 10)
    completed_output = run_cmd(["lpstat", "-W", "completed", "-o"])
    completed_jobs = []
    for line in completed_output.splitlines()[:10]:
        parts = line.split()
        if len(parts) >= 4:
            job_id = parts[0]
            user = parts[1]
            size = parts[2]
            date_str = " ".join(parts[3:])
            printer = ""
            if "-" in job_id:
                printer = job_id.rsplit("-", 1)[0]
            completed_jobs.append({
                "id": job_id,
                "printer": printer,
                "user": user,
                "size": size,
                "date": date_str,
                "status": "completed",
                "file": "(unknown)"
            })

    return {
        "cups_active": True,
        "printers": printers,
        "jobs": jobs,
        "completed_jobs": completed_jobs
    }

def discover_network_printers():
    devices = []
    output = run_cmd(["lpinfo", "-v"])
    import urllib.parse
    
    seen_uris = set()
    
    for line in output.splitlines():
        line = line.strip()
        if not line or not line.startswith("network "):
            continue
        parts = line.split(" ", 1)
        if len(parts) < 2:
            continue
        uri = parts[1].strip()
        
        if "://" not in uri:
            continue
            
        if uri in seen_uris:
            continue
        seen_uris.add(uri)
            
        name = uri
        if "dnssd://" in uri or "ipps://" in uri or "ipp://" in uri:
            try:
                host = uri.split("://", 1)[1].split("/", 1)[0]
                service_name = host.split("._", 1)[0]
                name = urllib.parse.unquote(service_name)
            except Exception:
                pass
        elif "socket://" in uri:
            name = f"Network Socket Printer ({uri.split('://', 1)[1]})"
            
        devices.append({
            "name": name,
            "uri": uri
        })
    return devices

def probe_ip(host):
    results = []
    host = host.strip()
    if not host:
        return results

    if "://" in host:
        try:
            host = host.split("://", 1)[1].split("/", 1)[0]
        except Exception:
            pass

    # Try Port 631 (IPP)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect((host, 631))
        s.close()
        results.append({
            "name": f"IPP Printer ({host})",
            "uri": f"ipp://{host}/ipp/print",
            "protocol": "ipp://"
        })
        results.append({
            "name": f"IPPS Printer ({host})",
            "uri": f"ipps://{host}/ipp/print",
            "protocol": "ipps://"
        })
    except Exception:
        pass

    # Try Port 9100 (AppSocket / JetDirect)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect((host, 9100))
        s.close()
        results.append({
            "name": f"AppSocket/JetDirect Printer ({host})",
            "uri": f"socket://{host}",
            "protocol": "socket://"
        })
    except Exception:
        pass

    # Try Port 515 (LPD)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect((host, 515))
        s.close()
        results.append({
            "name": f"LPD Printer ({host})",
            "uri": f"lpd://{host}/queue",
            "protocol": "lpd://"
        })
    except Exception:
        pass
        
    return results

def get_drivers(query=""):
    output = run_cmd(["lpinfo", "-m"])
    drivers = []
    query = query.strip().lower()
    
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            parts = line.split(" ", 1)
            uri = parts[0]
            description = parts[1] if len(parts) > 1 else uri
            
            if query:
                if query not in uri.lower() and query not in description.lower():
                    continue
            
            drivers.append({
                "uri": uri,
                "name": description
            })
            if len(drivers) >= 100:
                break
        except Exception:
            continue
            
    return drivers

def main():
    if "--discover" in sys.argv:
        devices = discover_network_printers()
        print(json.dumps(devices))
        sys.exit(0)
    elif "--probe" in sys.argv:
        try:
            idx = sys.argv.index("--probe")
            host = sys.argv[idx + 1]
            devices = probe_ip(host)
            print(json.dumps(devices))
        except Exception:
            print(json.dumps([]))
        sys.exit(0)
    elif "--drivers" in sys.argv:
        try:
            idx = sys.argv.index("--drivers")
            query = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else ""
            drivers = get_drivers(query)
            print(json.dumps(drivers))
        except Exception:
            print(json.dumps([]))
        sys.exit(0)

    interval = 3.0
    for arg in sys.argv[1:]:
        try:
            interval = float(arg)
        except ValueError:
            pass

    try:
        while True:
            data = get_printer_status()
            print(json.dumps(data), flush=True)
            time.sleep(interval)
    except KeyboardInterrupt:
        sys.exit(0)

if __name__ == "__main__":
    main()
