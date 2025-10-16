#!/usr/bin/env python3
import os
import requests
import json

def create_hathora_room(master_ip):
    """Create a Hathora room with the given master_ip as room config."""
    hathora_token = os.getenv('HATHORA_TOKEN')
    kimi_b_app_id = os.getenv('KIMI_B_APP_ID')
    room_config = json.dumps({"master_ip": master_ip})
    
    api_host = "hathora.io" if "hathora.io" in os.getenv("HATHORA_HOSTNAME") else "hathora.dev"

    response = requests.post(
        f"https://api.{api_host}/rooms/v2/{kimi_b_app_id}/create",
        headers={
            "Authorization": f"Bearer {hathora_token}",
            "Content-Type": "application/json"
        },
        json={
            "roomConfig": room_config,
            "region": "Washington_DC"
        }
    )
    
    if response.status_code == 201:
        room_data = response.json()
        print(f"Created room: {room_data['roomId']}")
    else:
        print(f"Failed to create room: {response.status_code} - {response.text}")
        exit(1)

def main():
    PORT = os.getenv('HTTP_PORT', 8000)
    initial_room_config = os.getenv('HATHORA_INITIAL_ROOM_CONFIG')
    if initial_room_config is None or initial_room_config == "":
        print("HATHORA_INITIAL_ROOM_CONFIG is not set, this is the primary")
        MASTER_IP = os.getenv('HATHORA_PRIVATE_IP')
        NODE_RANK = 0
        create_hathora_room(MASTER_IP)
    else:
        print("HATHORA_INITIAL_ROOM_CONFIG is set, this is the secondary")
        initial_room_config = json.loads(initial_room_config)
        MASTER_IP = initial_room_config['master_ip']
        NODE_RANK = 1

    from sglang.srt.entrypoints.http_server import launch_server
    from sglang.srt.server_args import ServerArgs

    launch_server(ServerArgs(
        model_path="moonshotai/Kimi-K2-Instruct",
        tp_size=16,
        dist_init_addr=f"{MASTER_IP}:20000",
        nnodes=2,
        node_rank=NODE_RANK,
        trust_remote_code=True,
        tool_call_parser="kimi_k2",
        port=PORT
    ))

if __name__ == "__main__":
    main()