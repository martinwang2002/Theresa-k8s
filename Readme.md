# GKE deployment notes


## Node pools preparation
| Node pool | Size | Image | Replicas | Tags | Price Notes |
| --- | --- | --- | --- | --- | --- |
| `ingress-pool` | `e2-micro` | COS | 1 | `https-server` | Free tier discount + free ip |
| `default-pool` | `e2-small` **spot** | COS | 1-3 | / | spot discount |
| `spot-pool` | `e2-custom-4-12288` **spot** | COS | 0-1 | Taints:spot=true:NoSchedule | spot discount |

Expected cost:
1. `ingress-pool`: $0.10 for free tier + SSD disk
1. `default-pool`: ~$5.10 for spot discount + spot ip + SSD disk
1. `spot-pool`: $2.00 for spot discount

Extra notes:
* Use 10G SSD for system drive

## Devops service account
```
kubectl apply -f ./Prod/devops-sa.yaml
```

We need to extract the authentication information for the new Service Account so we can set it up in the Endpoint in Azure DevOps. To do this, first list the secrets in the cluster using the following command
```
kubectl get secret
```
```
kubectl get secret [secret name] -o yaml > sa-secret.yaml
```

generate new k8s connection on `dev.azure.com`

## Ingress with static ip (no https load balancer)
Via **kubeip**

```
gcloud config set project {insert-your-GCP-project-name-here}
export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
```

Create kubeIP service account, role and iam policy binding:

```
gcloud iam service-accounts create kubeip-service-account --display-name "kubeIP"
gcloud iam roles create kubeip --project $PROJECT_ID --file ./ConfigMap/kubeip-iam-roles.yaml
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:kubeip-service-account@$PROJECT_ID.iam.gserviceaccount.com --role projects/$PROJECT_ID/roles/kubeip
```

Get the service account key and stick it in a secret:

```
gcloud iam service-accounts keys create key.json --iam-account kubeip-service-account@$PROJECT_ID.iam.gserviceaccount.com
kubectl create secret generic kubeip-key --from-file=key.json -n kube-system
```

Give yourself cluster admin RBAC:

```
kubectl create clusterrolebinding cluster-admin-binding \
   --clusterrole cluster-admin --user `gcloud config list --format 'value(core.account)'`
```


Create IP addresses and **label them**. with `kubeip=theresa-wiki-cluster`
```
gcloud beta compute addresses update theresa-wiki-ip --update-labels kubeip=theresa-wiki-cluster --region us-central1
```

```
kubectl apply -f ./ConfigMap/kubeip-ConfigMap.yaml
kubectl apply -f ./kubeip.yaml
```

## use nginx as *ingress*

### SSL
```
kubectl create secret tls theresa-wiki-tls-secret \
--key theresa.wiki.key \
--cert theresa.wiki.crt
```

### Envoy
```
kubectl apply -k ./ConfigMap/envoy
```

### Firewall
```
gcloud compute firewall-rules create tls-node-port --allow tcp:443
```

## storage system
### nfs server for AK_AB_DATA
1. Create persistent volume `theresa-wiki-pv` with 200GiB storage
1. `kubectl apply -f ./Prod/gke-storage-class.yaml` Storage class for the volume
1. `kubectl apply -f ./Prod/theresa-wiki-pv.yaml`
1. `kubectl apply -f ./Storage/theresa-wiki-pvc.yaml`
1. `kubectl apply -f ./nfs-server.yaml`
1. nfs-folder structure

    initiate nfs with folder structure
    ```
    |____AK_AB_DATA
    ```
    via ssh `kubectl exec nfs-server-0 -it -- sh`
1. Copy runtime files to folder
```
kubectl cp data.db nfs-server-0:/nfs-share/theresa-wiki-configs/theresa-drive
```

### theresa-wiki-configs
1. `kubectl apply -f ./Storage/theresa-wiki-configs-pvc.yaml`
1. theresa-wiki-configs structure
```
|____theresa-ak-ab
|____theresa-ak-ab-runtime
|____theresa-drive
```
1. `kubectl apply -f ./nfs-config.yaml`


## Services
1. Storages
```
kubectl apply -f ./Storage/theresa-wiki-configs.yaml
kubectl apply -f ./Storage/theresa-ak-ab-data.yaml
```
1. ConfigMaps
```
kubectl apply -f ./ConfigMap/redis-ConfigMap.yaml
kubectl apply -f ./ConfigMap/theresa-go-ConfigMap.yaml
```
1. Deployments / Cronjob
```
kubectl apply -f redis.yaml
kubectl apply -f theresa-go.yaml
kubectl apply -f theresa-frontend.yaml
kubectl apply -f theresa-drive.yaml
kubectl apply -f theresa-ak-ab-sa.yaml
kubectl apply -f theresa-ak-ab.yaml
```

## Rolling update
*Remember to change tag*
```
kubectl set image deployment/my-deployment mycontainer=myimage:latest
```


Other commands used
```
kubectl delete cronjobs --all -n default
kubectl delete deployment --all -n default
kubectl delete all --all -n default
kubectl delete pvc --all 
kubectl delete pv --all 


kubectl apply -f ./Local
kubectl apply -f ./Storage
kubectl apply -f .
```

## service account with gke

kubectl create secret generic gcs-theresa-wiki-k8s-configs --from-file=key.json


## enable workload identity & config connector
use workload identity for service account


mkfs.ext4 -b 4096 -i 131072 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard -O dir_index,extent,flex_bg,bigalloc /dev/sdb
