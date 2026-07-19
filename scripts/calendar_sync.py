#!/usr/bin/env python3
import os
import sys
import json
import argparse
import datetime
import urllib.request
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
import webbrowser
from pathlib import Path

# Path configurations
CONFIG_DIR = Path(os.path.expanduser("~/.config/ambxst"))
EVENTS_FILE = CONFIG_DIR / "calendar_events.json"
TOKENS_FILE = CONFIG_DIR / "calendar_tokens.json"

def load_json(path, default=None):
    if default is None:
        default = []
    if not path.exists():
        return default
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default

def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    try:
        os.chmod(path, 0o600)
    except Exception:
        pass

class OAuthHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        code = params.get("code")
        
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        
        if code:
            self.server.auth_code = code[0]
            html = """
            <html>
            <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background-color: #121212; color: #ffffff;">
                <h2 style="color: #4CAF50;">Xác thực thành công!</h2>
                <p>Bạn có thể đóng cửa sổ trình duyệt này và quay lại Dashboard.</p>
            </body>
            </html>
            """
            self.wfile.write(html.encode("utf-8"))
        else:
            self.wfile.write(b"Failed to get authorization code.")

def run_auth_server(client_id, client_secret):
    server = HTTPServer(("localhost", 0), OAuthHandler)
    port = server.server_address[1]
    server.auth_code = None
    
    redirect_uri = f"http://localhost:{port}"
    scope = "https://www.googleapis.com/auth/calendar.events"
    auth_url = (
        "https://accounts.google.com/o/oauth2/v2/auth?"
        + urllib.parse.urlencode({
            "response_type": "code",
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "scope": scope,
            "access_type": "offline",
            "prompt": "consent",
        })
    )
    
    print(json.dumps({"auth_url": auth_url}), flush=True)
    try:
        webbrowser.open(auth_url)
    except Exception as e:
        sys.stderr.write(f"Failed to open browser: {e}\n")
    
    server.handle_request()
    
    if server.auth_code:
        token_url = "https://oauth2.googleapis.com/token"
        data = urllib.parse.urlencode({
            "code": server.auth_code,
            "client_id": client_id,
            "client_secret": client_secret,
            "redirect_uri": redirect_uri,
            "grant_type": "authorization_code",
        }).encode("utf-8")
        
        req = urllib.request.Request(token_url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"})
        try:
            with urllib.request.urlopen(req) as res:
                tokens = json.loads(res.read().decode("utf-8"))
                tokens["client_id"] = client_id
                tokens["client_secret"] = client_secret
                tokens["expires_at"] = datetime.datetime.now().timestamp() + tokens.get("expires_in", 3600)
                save_json(TOKENS_FILE, tokens)
                print(json.dumps({"status": "success", "message": "Tokens saved successfully."}), flush=True)
                return True
        except Exception as e:
            print(json.dumps({"status": "error", "message": f"Token exchange failed: {e}"}), flush=True)
            return False
    else:
        print(json.dumps({"status": "error", "message": "No auth code received."}), flush=True)
        return False

def get_access_token():
    tokens = load_json(TOKENS_FILE, {})
    if not tokens:
        return None
    
    now = datetime.datetime.now().timestamp()
    if tokens.get("expires_at", 0) > now + 60:
        return tokens.get("access_token")
    
    refresh_token = tokens.get("refresh_token")
    client_id = tokens.get("client_id")
    client_secret = tokens.get("client_secret")
    if not refresh_token or not client_id or not client_secret:
        return None
    
    token_url = "https://oauth2.googleapis.com/token"
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }).encode("utf-8")
    
    req = urllib.request.Request(token_url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req) as res:
            new_tokens = json.loads(res.read().decode("utf-8"))
            tokens["access_token"] = new_tokens["access_token"]
            tokens["expires_at"] = datetime.datetime.now().timestamp() + new_tokens.get("expires_in", 3600)
            save_json(TOKENS_FILE, tokens)
            return tokens["access_token"]
    except Exception as e:
        sys.stderr.write(f"Failed to refresh access token: {e}\n")
        return None

def expand_recurrence(event, start_query, end_query):
    occurrences = []
    
    orig_start_str = event.get("start_time")
    orig_end_str = event.get("end_time")
    if not orig_start_str or not orig_end_str:
        return occurrences
    
    try:
        # standard ISO formats are YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD
        # if only date, pad with time
        if "T" not in orig_start_str:
            orig_start_str += "T00:00:00"
        if "T" not in orig_end_str:
            orig_end_str += "T00:00:00"
            
        # strip timezone offset if any (+07:00 or Z) for datetime parsing
        clean_start = orig_start_str.split("+")[0].split("Z")[0]
        clean_end = orig_end_str.split("+")[0].split("Z")[0]
        
        orig_start_dt = datetime.datetime.fromisoformat(clean_start)
        orig_end_dt = datetime.datetime.fromisoformat(clean_end)
    except Exception as e:
        sys.stderr.write(f"Error parsing date times: {e}\n")
        return occurrences
        
    orig_date = orig_start_dt.date()
    duration = orig_end_dt - orig_start_dt
    recurrence = event.get("recurrence", "none")
    
    if recurrence == "none":
        if start_query <= orig_date <= end_query:
            occurrences.append({
                "id": event["id"],
                "parent_id": event["id"],
                "summary": event.get("summary", ""),
                "description": event.get("description", ""),
                "start_time": orig_start_str,
                "end_time": orig_end_str,
                "date": orig_date.isoformat(),
                "recurrence": recurrence,
                "is_occurrence": False
            })
        return occurrences
        
    recurrence_until_str = event.get("recurrence_until")
    recurrence_until = None
    if recurrence_until_str:
        try:
            recurrence_until = datetime.date.fromisoformat(recurrence_until_str)
        except Exception:
            pass
            
    recurrence_count = event.get("recurrence_count")
    
    # If count is specified, we must count from orig_date onwards
    if recurrence_count is not None:
        try:
            count = int(recurrence_count)
        except ValueError:
            count = None
            
        if count is not None:
            matches = 0
            curr_date = orig_date
            while matches < count and curr_date <= end_query:
                if recurrence_until and curr_date > recurrence_until:
                    break
                    
                match = False
                if recurrence == "daily":
                    match = True
                elif recurrence == "weekly":
                    match = (curr_date.weekday() == orig_date.weekday())
                elif recurrence == "monthly":
                    match = (curr_date.day == orig_date.day)
                elif recurrence == "yearly":
                    match = (curr_date.month == orig_date.month and curr_date.day == orig_date.day)
                    
                if match:
                    matches += 1
                    if curr_date >= start_query:
                        occ_start = datetime.datetime.combine(curr_date, orig_start_dt.time())
                        occ_end = occ_start + duration
                        occurrences.append({
                            "id": f"{event['id']}_{curr_date.isoformat()}",
                            "parent_id": event["id"],
                            "summary": event.get("summary", ""),
                            "description": event.get("description", ""),
                            "start_time": occ_start.isoformat(),
                            "end_time": occ_end.isoformat(),
                            "date": curr_date.isoformat(),
                            "recurrence": recurrence,
                            "is_occurrence": True
                        })
                curr_date += datetime.timedelta(days=1)
            return occurrences

    # Normal loop with end_query and recurrence_until limit
    curr_date = max(start_query, orig_date)
    loop_end = end_query
    if recurrence_until:
        loop_end = min(end_query, recurrence_until)
        
    while curr_date <= loop_end:
        match = False
        if recurrence == "daily":
            match = True
        elif recurrence == "weekly":
            match = (curr_date.weekday() == orig_date.weekday())
        elif recurrence == "monthly":
            match = (curr_date.day == orig_date.day)
        elif recurrence == "yearly":
            match = (curr_date.month == orig_date.month and curr_date.day == orig_date.day)
            
        if match:
            occ_start = datetime.datetime.combine(curr_date, orig_start_dt.time())
            occ_end = occ_start + duration
            occurrences.append({
                "id": f"{event['id']}_{curr_date.isoformat()}",
                "parent_id": event["id"],
                "summary": event.get("summary", ""),
                "description": event.get("description", ""),
                "start_time": occ_start.isoformat(),
                "end_time": occ_end.isoformat(),
                "date": curr_date.isoformat(),
                "recurrence": recurrence,
                "is_occurrence": True
            })
        curr_date += datetime.timedelta(days=1)
        
    return occurrences

def list_events(start_str=None, end_str=None):
    events = load_json(EVENTS_FILE, [])
    events = [e for e in events if not e.get("deleted", False)]
    
    if not start_str or not end_str:
        print(json.dumps(events, ensure_ascii=False))
        return
        
    start_query = datetime.date.fromisoformat(start_str)
    end_query = datetime.date.fromisoformat(end_str)
    
    all_occurrences = []
    for e in events:
        all_occurrences.extend(expand_recurrence(e, start_query, end_query))
        
    all_occurrences.sort(key=lambda x: x["start_time"])
    print(json.dumps(all_occurrences, ensure_ascii=False))

def add_event(event_data_str):
    events = load_json(EVENTS_FILE, [])
    try:
        new_event = json.loads(event_data_str)
    except Exception as e:
        print(json.dumps({"status": "error", "message": f"Invalid JSON data: {e}"}))
        return
        
    if "id" not in new_event:
        import uuid
        new_event["id"] = "local_" + str(uuid.uuid4())
        
    new_event["updated"] = datetime.datetime.now().timestamp()
    new_event["deleted"] = False
    
    events = [e for e in events if e.get("id") != new_event["id"]]
    events.append(new_event)
    save_json(EVENTS_FILE, events)
    print(json.dumps({"status": "success", "event": new_event}))

def delete_event(event_id):
    events = load_json(EVENTS_FILE, [])
    found = False
    
    # Check if this ID contains recurrence date suffix, extract parent ID
    parent_id = event_id
    if "_" in event_id and not event_id.startswith("local_"):
        # Could be google event with occurrence suffix
        parts = event_id.split("_")
        if len(parts) > 1 and len(parts[-1]) == 10: # YYYY-MM-DD
            parent_id = "_".join(parts[:-1])
    elif "_" in event_id and event_id.startswith("local_"):
        # e.g., local_uuid_2026-06-15
        parts = event_id.split("_")
        if len(parts) > 2 and len(parts[-1]) == 10:
            parent_id = "_".join(parts[:-1])

    for e in events:
        if e.get("id") == parent_id:
            e["deleted"] = True
            e["updated"] = datetime.datetime.now().timestamp()
            found = True
            break
            
    if found:
        save_json(EVENTS_FILE, events)
        print(json.dumps({"status": "success", "message": f"Event {parent_id} marked as deleted."}))
    else:
        print(json.dumps({"status": "error", "message": f"Event {parent_id} not found."}))

def make_gcal_request(url, method="GET", body=None, access_token=None):
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as res:
            content = res.read().decode("utf-8")
            if not content or res.status == 204:
                return {}, res.status
            return json.loads(content), res.status
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"Google Calendar API Error ({e.code}): {e.read().decode('utf-8')}\n")
        return None, e.code
    except Exception as e:
        sys.stderr.write(f"Google Calendar API Request failed: {e}\n")
        return None, 500

def map_gcal_to_local(gcal_event):
    start = gcal_event.get("start", {})
    end = gcal_event.get("end", {})
    
    start_time = start.get("dateTime") or start.get("date")
    end_time = end.get("dateTime") or end.get("date")
    
    recurrence_str = "none"
    recurrence_until = None
    recurrence_count = None
    
    gcal_recurrence = gcal_event.get("recurrence", [])
    if gcal_recurrence:
        rrule = gcal_recurrence[0]
        if "FREQ=DAILY" in rrule:
            recurrence_str = "daily"
        elif "FREQ=WEEKLY" in rrule:
            recurrence_str = "weekly"
        elif "FREQ=MONTHLY" in rrule:
            recurrence_str = "monthly"
        elif "FREQ=YEARLY" in rrule:
            recurrence_str = "yearly"
            
        import re
        until_match = re.search(r"UNTIL=(\d{8}(T\d{6}Z)?)", rrule)
        if until_match:
            until_str = until_match.group(1)
            try:
                until_date_str = until_str[:8]
                recurrence_until = datetime.date(
                    int(until_date_str[:4]),
                    int(until_date_str[4:6]),
                    int(until_date_str[6:8])
                ).isoformat()
            except Exception:
                pass
                
        count_match = re.search(r"COUNT=(\d+)", rrule)
        if count_match:
            try:
                recurrence_count = int(count_match.group(1))
            except Exception:
                pass
            
    updated_str = gcal_event.get("updated")
    updated_ts = datetime.datetime.now().timestamp()
    if updated_str:
        try:
            clean_up = updated_str.replace("Z", "+00:00")
            updated_ts = datetime.datetime.fromisoformat(clean_up).timestamp()
        except Exception:
            pass
            
    return {
        "id": "gcal_" + gcal_event["id"],
        "summary": gcal_event.get("summary", ""),
        "description": gcal_event.get("description", ""),
        "start_time": start_time,
        "end_time": end_time,
        "recurrence": recurrence_str,
        "recurrence_until": recurrence_until,
        "recurrence_count": recurrence_count,
        "gcal_id": gcal_event["id"],
        "updated": updated_ts,
        "deleted": gcal_event.get("status") == "cancelled"
    }

def map_local_to_gcal(local_event):
    start_val = local_event.get("start_time")
    end_val = local_event.get("end_time")
    
    start_key = "dateTime" if "T" in start_val else "date"
    end_key = "dateTime" if "T" in end_val else "date"
    
    gcal_event = {
        "summary": local_event.get("summary", ""),
        "description": local_event.get("description", ""),
        "start": {start_key: start_val},
        "end": {end_key: end_val}
    }
    
    if start_key == "dateTime":
        if "+" not in start_val and "-" not in start_val[10:]:
            gcal_event["start"]["timeZone"] = "Asia/Ho_Chi_Minh"
            gcal_event["end"]["timeZone"] = "Asia/Ho_Chi_Minh"
            
    recurrence = local_event.get("recurrence", "none")
    if recurrence != "none":
        rrule = f"RRULE:FREQ={recurrence.upper()}"
        until = local_event.get("recurrence_until")
        if until:
            clean_until = until.replace("-", "")
            rrule += f";UNTIL={clean_until}T235959Z"
        count = local_event.get("recurrence_count")
        if count:
            rrule += f";COUNT={count}"
        gcal_event["recurrence"] = [rrule]
        
    return gcal_event

def sync_events():
    access_token = get_access_token()
    if not access_token:
        print(json.dumps({"status": "error", "message": "Chưa xác thực tài khoản Google. Vui lòng liên kết tài khoản trong Cài đặt."}))
        return
        
    local_events = load_json(EVENTS_FILE, [])
    
    url = "https://www.googleapis.com/calendar/v3/calendars/primary/events?showDeleted=true&maxResults=250"
    gcal_data, status = make_gcal_request(url, access_token=access_token)
    if gcal_data is None:
        print(json.dumps({"status": "error", "message": f"Lỗi lấy dữ liệu Google Calendar: HTTP {status}"}))
        return
        
    gcal_items = gcal_data.get("items", [])
    gcal_by_id = {item["id"]: item for item in gcal_items}
    new_local_events = []
    
    for le in local_events:
        gcal_id = le.get("gcal_id")
        
        if le.get("deleted", False):
            if gcal_id:
                del_url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events/{gcal_id}"
                make_gcal_request(del_url, method="DELETE", access_token=access_token)
                continue
            else:
                continue
                
        if not gcal_id:
            post_url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
            gcal_body = map_local_to_gcal(le)
            res_item, code = make_gcal_request(post_url, method="POST", body=gcal_body, access_token=access_token)
            if res_item and "id" in res_item:
                le["gcal_id"] = res_item["id"]
                le["id"] = "gcal_" + res_item["id"]
                updated_str = res_item.get("updated")
                if updated_str:
                    try:
                        clean_up = updated_str.replace("Z", "+00:00")
                        le["updated"] = datetime.datetime.fromisoformat(clean_up).timestamp()
                    except Exception:
                        le["updated"] = datetime.datetime.now().timestamp()
                new_local_events.append(le)
            else:
                new_local_events.append(le)
        else:
            ge = gcal_by_id.get(gcal_id)
            if ge:
                if ge.get("status") == "cancelled":
                    continue
                    
                local_up = le.get("updated", 0)
                g_updated_str = ge.get("updated")
                g_updated = 0
                if g_updated_str:
                    try:
                        clean_up = g_updated_str.replace("Z", "+00:00")
                        g_updated = datetime.datetime.fromisoformat(clean_up).timestamp()
                    except Exception:
                        pass
                
                if local_up > g_updated + 2:
                    put_url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events/{gcal_id}"
                    gcal_body = map_local_to_gcal(le)
                    res_item, code = make_gcal_request(put_url, method="PUT", body=gcal_body, access_token=access_token)
                    if res_item:
                        updated_str = res_item.get("updated")
                        if updated_str:
                            try:
                                clean_up = updated_str.replace("Z", "+00:00")
                                le["updated"] = datetime.datetime.fromisoformat(clean_up).timestamp()
                            except Exception:
                                pass
                    new_local_events.append(le)
                elif g_updated > local_up + 2:
                    updated_le = map_gcal_to_local(ge)
                    new_local_events.append(updated_le)
                else:
                    new_local_events.append(le)
                
                gcal_by_id.pop(gcal_id, None)
            else:
                continue

    for gcal_id, ge in gcal_by_id.items():
        if ge.get("status") == "cancelled":
            continue
        new_le = map_gcal_to_local(ge)
        new_local_events.append(new_le)
        
    save_json(EVENTS_FILE, new_local_events)
    print(json.dumps({"status": "success", "message": "Synchronization completed successfully."}))

def check_auth_status():
    tokens = load_json(TOKENS_FILE, {})
    status_str = "unauthenticated"
    client_id = ""
    client_secret = ""
    if tokens:
        client_id = tokens.get("client_id", "")
        client_secret = tokens.get("client_secret", "")
        now = datetime.datetime.now().timestamp()
        if tokens.get("expires_at", 0) > now + 60:
            status_str = "authenticated"
        else:
            access_token = get_access_token()
            if access_token:
                status_str = "authenticated"
            else:
                status_str = "expired"
                
    print(json.dumps({
        "status": status_str,
        "client_id": client_id,
        "client_secret": client_secret
    }))

def main():
    parser = argparse.ArgumentParser(description="Ambxst Google Calendar Sync backend")
    parser.add_argument("--list", action="store_true", help="List local occurrences")
    parser.add_argument("--start", type=str, help="Start query date (YYYY-MM-DD)")
    parser.add_argument("--end", type=str, help="End query date (YYYY-MM-DD)")
    parser.add_argument("--add", type=str, help="Add local event (JSON format)")
    parser.add_argument("--delete", type=str, help="Delete local event by ID")
    parser.add_argument("--auth", action="store_true", help="Start OAuth server")
    parser.add_argument("--client-id", type=str, help="OAuth Client ID")
    parser.add_argument("--client-secret", type=str, help="OAuth Client Secret")
    parser.add_argument("--sync", action="store_true", help="Perform bidirectional sync")
    parser.add_argument("--status", action="store_true", help="Check OAuth credentials status")
    args = parser.parse_args()
    
    if args.list:
        list_events(args.start, args.end)
    elif args.add:
        add_event(args.add)
    elif args.delete:
        delete_event(args.delete)
    elif args.auth:
        if not args.client_id or not args.client_secret:
            print(json.dumps({"status": "error", "message": "--client-id and --client-secret are required for authentication."}))
            sys.exit(1)
        run_auth_server(args.client_id, args.client_secret)
    elif args.sync:
        sync_events()
    elif args.status:
        check_auth_status()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
