Learn kubeseal workflow and see what its like to fail and recover

1. create kind cluster
2. create example secret
3. export encrypted secret
4. extract private key from cluster
5. delete cluster
6. create another kind cluster
7. import private key from first cluster
8. import encrypted secret
9. decode secret
10. observe secret is decoded successfully

references
* https://github.com/bitnami-labs/sealed-secrets#sealed-secrets-for-kubernetes
* https://github.com/bitnami-labs/sealed-secrets/issues/25#issuecomment-311004315
