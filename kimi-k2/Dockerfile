FROM lmsysorg/sglang:v0.5.3.post1-cu129-amd64

WORKDIR /app

COPY entrypoint.sh .
COPY create_hathora_room.py .

ENTRYPOINT ["bash", "./entrypoint.sh"]

