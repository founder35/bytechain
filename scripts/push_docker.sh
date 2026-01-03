#!/bin/bash
set -e

IMAGE_NAME="bytedex/bytechain"
TAG="testnet"

echo "Building Docker image: $IMAGE_NAME:$TAG"
docker build -t $IMAGE_NAME:$TAG .

echo "Logging in to Docker Hub (if needed)..."
docker login

echo "Pushing image to Docker Hub..."
docker push $IMAGE_NAME:$TAG

echo "Done! Image pushed to $IMAGE_NAME:$TAG"
