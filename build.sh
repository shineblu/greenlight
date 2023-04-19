#!/usr/bin/sh
docker-compose down
# sometimes need: aa-teardown
./scripts/image_build.sh mcxxi release-v2 >/dev/null
docker-compose up -d
