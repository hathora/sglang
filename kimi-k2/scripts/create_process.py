#!/usr/bin/env python3
import os, sys, json, requests, argparse

parser = argparse.ArgumentParser(description="Create a Hathora room with master IP")
parser.add_argument("master_ip", help="Master node IP address")
args = parser.parse_args()

hathora_token = os.getenv('HATHORA_TOKEN')
b_app_id = os.getenv('B_APP_ID')
primary_process_id = os.getenv('HATHORA_PROCESS_ID')
api_host = "hathora.io" if "hathora.io" in os.getenv("HATHORA_HOSTNAME", "") else "hathora.dev"

room_config = json.dumps({
    "master_ip": args.master_ip,
    "process_id": primary_process_id
})

response = requests.post(
    f"https://api.{api_host}/rooms/v2/{b_app_id}/create",
    headers={"Authorization": f"Bearer {hathora_token}", "Content-Type": "application/json"},
    json={"roomConfig": room_config, "region": "Washington_DC"}
)

if response.status_code == 201:
    room_data = response.json()
    print(room_data['processId'])
else:
    sys.exit(f"Failed to create room: {response.status_code} - {response.text}")
