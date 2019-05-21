#!/bin/bash

if [ -z "${VE_OUTPUT}" ]
then
	echo Must set VE_DOCKER_IN \(location of Dockerfile etc.\)
	exit 1
fi

if [ -z "${VE_DOCKER_IN}" ]
then
	echo Must set VE_DOCKER_IN \(location of Dockerfile etc.\)
	exit 1
fi

if [ -z "${VE_DOCKER_OUT}" ]
then
	echo Must set VE_DOCKER_OUT \(Location in which to build Docker image\)
	exit 1
fi

if [ -z "${DOCKERFILE}" ]
then
	echo Must set DOCKERFILE \(Name of Dockerfile\)
	exit 1
fi

mkdir -p $(VE_DOCKER_OUT)/home/visioneval/models
mkdir -p $(VE_DOCKER_OUT)/Data

cp -R $(VE_RUNTIME)/models/* (VE_DOCKER_OUT)/home/visioneval/models/
cp $(VE_DOCKER_IN)/.dockerignore $(VE_DOCKER_OUT)
cp -a $(VE_DOCKER_IN)/home/* $(VE_DOCKER_OUT)/home/
cd $(VE_DOCKER_OUT)
docker build -f ${DOCKERFILE} -t visioneval .
