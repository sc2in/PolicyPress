#!/usr/bin/env bash
DRAFT=-d
if [[ $PUBLISH == 1 ]]; then
  DRAFT=""
fi

cd /data
pnpm i
pnpm build
./pandoc.sh $DRAFT