#!/usr/bin/env bash

# push deploy script to all servers
for i in controlplane node01 node02
do
  vagrant upload ~/code/k8s-labs/build/deploy.sh /home/vagrant/ $i
  vagrant ssh -c "bash deploy.sh" $i 
done

# initialise kubernetes
vagrant ssh -c "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.56.11" controlplane

# copy admin kube config to vagrant user
vagrant ssh -c "mkdir -p /home/vagrant/.kube" controlplane
vagrant ssh -c "sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config" controlplane
vagrant ssh -c "sudo chown vagrant. /home/vagrant/.kube/config" controlplane

# copy vagrant kube auth file to local
vagrant ssh -c "cat .kube/config" controlplane > ~/.kube/config

# deploy network addon to kubernetes 
kubectl apply -f https://reweave.azurewebsites.net/k8s/v1.29/net.yaml

# edit weave-net config to include 10.244 range
kubectl get ds weave-net -n kube-system -o yaml | tee weave.yaml >/dev/null 2>&1
sed '/^        - name: INIT_C.*/i\n       - name: IPALLOC_RANGE\n          value: 10.244.0.0/16' weave.yaml
kubectl apply -f weave.yaml

# retrieve join command from controlplane
vagrant ssh -c "kubeadm token create --print-join-command" controlplane > join.sh
for node in node01 node02
do
  vagrant upload join.sh /home/vagrant/ $i
  vagrant ssh -c "bash join.sh" $i 
done

# restart CoreDNS service
kubectl rollout restart -n kube-system deployment/coredns

############## deploy the kubernetes dashboard
# Add kubernetes-dashboard repository
vagrant ssh -c "helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/" controlplane
# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
vagrant ssh -c "helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard" controlplane

