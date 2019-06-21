#!/usr/bin/env bash

docker build -t development --target development .
docker run development
