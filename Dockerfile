FROM ubuntu:xenial as build-env

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
	build-essential \
	clang \
	cmake \
	python \
	git \
 && rm -rf /var/lib/apt/lists/*
