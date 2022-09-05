#!/bin/bash

set -e
set -x

base="$(pwd)"
cd "$base"

rm -f main.key
rm -f mysealedsecret1.yaml
rm -f mysealedsecret2.json
rm -f mysealedsecret2.yaml
rm -f mysecret2.json
rm -f mysecret2.yaml

kind delete cluster

kubectl config get-contexts

helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update sealed-secrets

kind create cluster --wait 3m
helm install sealed-secrets --namespace kube-system sealed-secrets/sealed-secrets

kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sealed-secrets --namespace kube-system

# keep this public/private key OMG safe:
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml >"$base/main.key"
ls -la "$base/main.key"

kubectl create secret generic secret-name --dry-run=client --from-literal=foo=bar -o yaml |
    kubeseal \
        --controller-name=sealed-secrets \
        --controller-namespace=kube-system \
        --format yaml >"$base/mysealedsecret1.yaml"

ls -la "$base/mysealedsecret1.yaml"

echo -n 'PassW@rd1' | kubectl create secret generic mysecret --dry-run=client --from-file=mypassword=/dev/stdin -o yaml >"$base/mysecret2.yaml"
kubeseal --controller-name=sealed-secrets -o yaml <"$base/mysecret2.yaml" >"$base/mysealedsecret2.yaml"
ls -la "$base/mysecret2.yaml" "$base/mysealedsecret2.yaml"

kubectl create -f "$base/mysealedsecret2.yaml"
kubectl get secret mysecret -o jsonpath="{.data.mypassword}" | base64 --decode
echo

kubectl get secrets --all-namespaces
kubectl get secrets --all-namespaces | sed 1d | wc -l

# invoke disaster
kind delete cluster

# create new cluster
kind create cluster --wait 3m
helm install sealed-secrets --namespace kube-system sealed-secrets/sealed-secrets
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sealed-secrets --namespace kube-system

# re-add our private key and trigger controller to reload it
kubectl apply -f main.key
kubectl delete pods -l app.kubernetes.io/name=sealed-secrets -n kube-system

kubectl get pods -l app.kubernetes.io/name=sealed-secrets -n kube-system
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sealed-secrets --namespace kube-system

kubectl apply -f mysealedsecret2.yaml

kubectl get secrets --all-namespaces
kubectl get secrets --all-namespaces | sed 1d | wc -l

kubectl get secret mysecret -o jsonpath="{.data.mypassword}" | base64 --decode
echo
