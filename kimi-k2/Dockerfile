FROM lmsysorg/sglang:v0.5.3.post1-cu129-amd64

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ibutils && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh .
COPY create_hathora_room.py .

ENTRYPOINT ["bash", "./entrypoint.sh"]

