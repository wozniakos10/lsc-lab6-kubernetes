#!/bin/bash
set -e

echo "Step 1: Starting Minikube (if not already running)..."
minikube status || minikube start --cpus=2 --memory=4g --driver=docker

echo "Step 2: Checking Kubernetes connection..."
kubectl get nodes

echo "Step 3: Installing NFS server provisioner with Helm..."
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm install nfs-server-provisioner stable/nfs-server-provisioner \
  --set storageClass.name=nfs \
  --set persistence.enabled=true \
  --set persistence.size=10Gi

echo "Waiting for NFS server to be ready..."
sleep 30

echo "Step 4: Creating Persistent Volume Claim..."
cat > pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: web-content-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  resources:
    requests:
      storage: 1Gi
EOF
kubectl apply -f pvc.yaml

echo "Step 5: Creating Nginx Deployment..."
cat > nginx-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: web-content
        persistentVolumeClaim:
          claimName: web-content-pvc
EOF
kubectl apply -f nginx-deployment.yaml

echo "Step 6: Creating Nginx Service..."
cat > nginx-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF
kubectl apply -f nginx-service.yaml

echo "Step 7: Creating Content Copy Job..."
cat > content-copy-job.yaml << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: content-copy-job
spec:
  template:
    spec:
      containers:
      - name: content-creator
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo '<html><head><title>NFS Demo</title></head><body>' > /content/index.html
          echo '<h1>Hello from Kubernetes NFS!</h1>' >> /content/index.html
          echo '<p>This is a demonstration of NFS storage in Kubernetes.</p>' >> /content/index.html
          echo '<p>Current time when this file was generated: '$(date)'</p>' >> /content/index.html
          echo '</body></html>' >> /content/index.html
          echo "Content created successfully!"
        volumeMounts:
        - name: web-content
          mountPath: /content
      restartPolicy: Never
      volumes:
      - name: web-content
        persistentVolumeClaim:
          claimName: web-content-pvc
  backoffLimit: 4
EOF
kubectl apply -f content-copy-job.yaml

echo "Waiting for all components to be ready..."
sleep 10

echo "Checking status of all resources..."
kubectl get pods,pvc,svc,jobs

echo "Access your application at:"
minikube service nginx-service --url
