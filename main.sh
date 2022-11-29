#!/bin/bash

set -e
set -x
set -u

base="$(pwd)"
cd "$base"

# start clean
rm -rf "$base/secrets"
kind delete cluster --name sealed1
kind delete cluster --name sealed2

kind get clusters
kind create cluster --wait 3m --name sealed1

mkdir -p "$base/secrets"

kubectl config get-contexts

helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update sealed-secrets

helm install sealed-secrets --namespace kube-system sealed-secrets/sealed-secrets

kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sealed-secrets --namespace kube-system

# keep this public/private key OMG safe:
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml >"$base/secrets/main.key"
ls -la "$base/secrets/main.key"

echo -n 'PassW@rd1' | kubectl create secret generic mysecret --dry-run=client \
    --from-file=mypassword=/dev/stdin -o yaml >"$base/secrets/mysecret2.yaml"
kubeseal --controller-name=sealed-secrets -o yaml <"$base/secrets/mysecret2.yaml" >"$base/secrets/mysealedsecret2.yaml"
ls -la "$base/secrets/mysecret2.yaml" "$base/secrets/mysealedsecret2.yaml"

kubectl create -f "$base/secrets/mysealedsecret2.yaml"
kubectl get secret mysecret -o yaml -n default
kubectl get secret mysecret -o jsonpath="{.data.mypassword}" | base64 --decode
echo

kubectl get secrets --all-namespaces
kubectl get secrets --all-namespaces | sed 1d | wc -l

# invoke disaster
kind delete cluster --name sealed1

# create new cluster
kind create cluster --wait 3m --name sealed2
helm install sealed-secrets --namespace kube-system sealed-secrets/sealed-secrets
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sealed-secrets --namespace kube-system

# re-add our private key and trigger controller to reload it
kubectl apply -f "$base/secrets/main.key"
kubectl delete pods -l app.kubernetes.io/name=sealed-secrets -n kube-system

kubectl get pods -l app.kubernetes.io/name=sealed-secrets -n kube-system
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sealed-secrets --namespace kube-system

kubectl apply -f "$base/secrets/mysealedsecret2.yaml"

kubectl get secrets --all-namespaces
kubectl get secrets --all-namespaces | sed 1d | wc -l

kubectl get secret mysecret -o jsonpath="{.data.mypassword}" | base64 --decode
echo

kind delete cluster --name sealed2
