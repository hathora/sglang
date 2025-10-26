FROM lmsysorg/sglang:v0.5.4-cu129-amd64

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ibutils && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

ENTRYPOINT ["bash", "./entrypoint_router.sh"]
