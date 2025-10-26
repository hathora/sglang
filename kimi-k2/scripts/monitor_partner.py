#!/usr/bin/env python3
import os, sys, json, requests, argparse, time, signal

parser = argparse.ArgumentParser(description="Monitor a Hathora process")
parser.add_argument("process_id", help="Process ID to monitor")
args = parser.parse_args()

hathora_token = os.getenv('HATHORA_TOKEN')
b_app_id = os.getenv('B_APP_ID')
api_host = "hathora.io" if "hathora.io" in os.getenv("HATHORA_HOSTNAME", "") else "hathora.dev"

print(f"Monitoring process {args.process_id} every 5 seconds...")

while True:
    time.sleep(5)
    try:
        response = requests.get(
            f"https://api.{api_host}/processes/v3/{b_app_id}/{args.process_id}/info",
            headers={"Authorization": f"Bearer {hathora_token}"},
            timeout=5
        )

        if response.status_code != 200:
            print(f"Failed to get process status: {response.status_code}")
            continue

        process_data = response.json()
        status = process_data.get('status')

        # If process is no longer active, terminate
        if status not in ['active', 'starting']:
            print(f"Process status is '{status}', terminating")
            os.kill(1, signal.SIGTERM)
            sys.exit(1)

    except Exception as e:
        print(f"Error checking process status: {e}")
