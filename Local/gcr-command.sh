kubectl create secret docker-registry gcr-io-secret --docker-server gcr.io --docker-username _json_key --docker-email dev-test-gcr@theresa-wiki.iam.gserviceaccount.com --docker-password="$(cat gcr.json)"



kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "gcr-io-secret"}]}'
 