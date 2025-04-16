Start Minikube:
```
minikube start --cpus=2 --memory=4g --driver=docker
```

Install NFS Server Provisioner:
```
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm install nfs-server-provisioner stable/nfs-server-provisioner --set storageClass.name=nfs --set persistence.enabled=true --set persistence.size=10Gi
```

Create and apply resources:
```
kubectl apply -f pvc.yaml
kubectl apply -f nginx-deployment.yaml
kubectl apply -f nginx-service.yaml
kubectl apply -f content-copy-job.yaml
```

Check deployment status:
```
kubectl get pods,pvc,svc,jobs
```

Access the application:
```
minikube service nginx-service --url
```

These commands will set up an NFS storage solution, deploy an Nginx web server with 2 replicas, create shared storage, and populate it with a simple HTML page.


All neccessary configuration appears in `minikube-deploy.sh`. For run application execute:
```
bash minikube-deploy.sh
```