#!/bin/bash
# todo interface design and fucntion repeate?
set -euxo pipefail
# pesisistent netdev name

# systemctl is-enabled firewalld

#systemctl status firewalld


# cat /etc/selinux/config 
# getenforce
#  disabled


# yum update

# reboot

#ref:https://kubernetes.io/docs/setup/independent/install-kubeadm/
#  ansible override  nice ,now will repeate
# or use the temp file as tag to whetethe have set or look at result and not to dup or repl!!!!

registrname=registr.dnion.com
registrip=183.131.215.156

echo -en "Enter k8s master Hostname such as k8s01.dnion.com"
read mastername
# we only one ip!
masterip=`ip addr show eth2 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`
hostnamectl set-hostname $mastername


#set hosts
cat <<EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
${masterip} ${mastername}
${registrip} ${registrname}
EOF

#disble swap 
#mabye cannot rerun
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

http_proxy="http://creativebaul.asuscomm.com:8123/"
#no_proxy="registr.dnion.com,localhost,127.0.0.1,183.131.215.156,10.96.0.0/12,10.244.0.0/16"
#maybe use subnet for masterip net
#must use the hostname, not the ip. docker pull will use the hostname!!!
no_proxy="${mastername},localhost,127.0.0.1,${masterip},${registrip},${registrname},10.96.0.0/12,10.244.0.0/16"
https_proxy="http://creativebaul.asuscomm.com:8123"


# docker install 
https_proxy=$https_proxy yum install -y yum-utils   device-mapper-persistent-data   lvm2
yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-17.12.1.ce
systemctl enable docker && systemctl start docker
mkdir -p /etc/systemd/system/docker.service.d
cat <<EOF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${http_proxy}" "NO_PROXY=${no_proxy}"
EOF

cat <<EOF > /etc/systemd/system/docker.service.d/https-proxy.conf
[Service]
Environment="HTTPS_PROXY=${http_proxy}" "NO_PROXY=${no_proxy}"
EOF

#centos 7 defaout ext4 support overylay2,but xfs need reformat.
#append
#cat >>/etc/docker/daemon.json <<EOL
#{
#  "storage-driver": "overlay2",
#  "storage-opts": ["overlay2.override_kernel_check=true"]
#}
#EOL
#replace overwrite
cat <<EOF > /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"]
}
EOF

systemctl daemon-reload
systemctl restart docker


#kube install 

#centos 7 defaout cgroups and k8s defautl use cgroup

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# -e,only look at later cmd true..
#but -o pipefial enven first cmd fail, will exit.
#-u not sed var as fail
#$(setenforce 0) || true
if setenforce 0; then
  echo "setenforce success"
else
  echo "have setenforce 0 before"
fi

#if set proxy,then not need .
#ip_resolve=4 in /etc/yum.conf
#echo 'ip_resolve=4' >> /etc/yum.conf
#check and add ,not dup
#set yum config

https_proxy=$https_proxy yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet
#for some centos 7 
# ipv6 should disable for now ,dashboard?
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.disable_ipv6 = 1
EOF
sysctl --system


#[root@registr ddns]# cat /var/lib/kubelet/kubeadm-flags.env
#KUBELET_KUBEADM_ARGS=--cgroup-driver=cgroupfs --cni-bin-dir=/opt/cni/bin --cni-conf-dir=/etc/cni/net.d --network-plugin=cni
#[root@registr ddns]# cat /etc/default/kubelet
#cat: /etc/default/kubelet: No such file or director
#KUBELET_KUBEADM_EXTRA_ARGS=--cgroup-driver=<value>


 #no_proxy='183.131.215.156,10.96.0.0/12,10.244.0.0/16,127.0.0.1,localhost,registr.dnion.com' https_proxy='http://creativebaul.asuscomm.com:8123' kubeadm -v 2 init --pod-network-cidr 10.244.0.0/16
#no_proxy='${no_proxy}' https_proxy='${https_proxy}' kubeadm -v 2 init --pod-network-cidr 10.244.0.0/16

# cluster init
#  cannot rerun 
no_proxy=${no_proxy} https_proxy=${https_proxy} kubeadm -v 2 init --pod-network-cidr 10.244.0.0/16
echo Please save the kubeadm join command from the above output to be able to allow other nodes to join in the future.
read -n 1 -s -r -p "Press any key to continue"

#  cannot rerun 
#echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc
cat <<EOT >> /root/.bashrc
alias kc='kubectl'
alias kcpod='kubectl get pods --all-namespaces -o wide'
alias kcsvc='kubectl get svc --all-namespaces'
alias kcdpl='kubectl get deployment --all-namespaces'
alias kcds='kubectl get ds --all-namespaces'
alias kced='kubectl get ed --all-namespaces'
alias kcexe='kubectl exec -it'
alias kclog='kubectl logs'
alias kcwhy='kubectl describe'
HISTSIZE=10000
HISTFILESIZE=20000
export KUBECONFIG=/etc/kubernetes/admin.conf
EOT

source /root/.bashrc

#now blow manual op ,later scriptes or ansible

kubectl taint nodes --all node-role.kubernetes.io/master-


# flannel install,default vxlan 
#git clone https://github.com/inevity/k8smetal.git
#or git pull
#maybe we need change flannel config later
pushd k8smetal
#wget https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml
#kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel
kubectl get po,svc  --all-namespaces
#check coredns have ready
#kcpod -o wide|grep coredns|awk '{print $4}'|xarg 
#[root@k8s01 k8smetal]# kubectl get pods --all-namespaces -o=jsonpath="{..status.phase}" -l k8s-app=kube-dns
#Pending Pending[root@k8s01 k8smetal]#
#Running Running
#kubectl get pods --all-namespaces -o=jsonpath="{..status.containerStatuses[*].ready}" -l k8s-app=kube-dns
#true true[root@k8s01 k8smetal]#
popd


## metric server install  for hpa use
git clone https://github.com/kubernetes-incubator/metrics-server.git
##cd metrics-server/
pushd metrics-server
##
##        - /metrics-server
##      #  - --source=kubernetes.summary_api:''
##      #  - --source=kubernetes:${MASTER_URL}?useServiceAccount=true&kubeletHttps=true&kubeletPort=10250
##        - --source=kubernetes.summary_api:https://kubernetes.default?kubeletPort=10250&kubeletHttps=true&insecure=true
#        - --source=
#sed -i 's/^acl verizonfios.*/acl verizonfios src 202.1.2.3/' /etc/squid/squid.conf
#sed -i 's|^        - --source=.*|        - --source=kubernetes.summary_api:https://kubernetes.default?kubeletPort=10250&kubeletHttps=true&insecure=true/' deploy/1.8+/metrics-server-deployment.yaml
sed -i 's|^        - --source=.*|        - --source=kubernetes.summary_api:https://kubernetes.default?kubeletPort=10250\&kubeletHttps=true\&insecure=true|' deploy/1.8+/metrics-server-deployment.yaml
#
##[root@registr metrics-server]# cat deploy/1.8+/metrics-server-deployment.yaml
kubectl create -f deploy/1.8+
popd

#todo docker register create:
mkdir -p /etc/docker/certs.d/registr.dnion.com:5000/
scp -pr root@registr.dnion.com:/certs/ca.crt /etc/docker/certs.d/registr.dnion.com\:5000/



##docker login ...
#

# cpu bind static config  or share
#mkdir -p /sys/fs/cgroup/cpuset/system.slice/kubelet.service
#mkdir -p /sys/fs/cgroup/hugetlb/system.slice/kubelet.service
#echo 'KUBELET_EXTRA_ARGS=--cpu-manager-policy=static --kube-reserved=cpu=4000m  --kube-reserved-cgroup=/system.slice/kubelet.service --system-reserved=cpu=2000m --system-reserved-cgroup=/system.slice --enforce-node-allocatable=pods,kube-reserved,system-reserved' > /etc/sysconfig/kubelet
##KUBELET_EXTRA_ARGS=--allowed-unsafe-sysctls='net.ipv4.conf*'
#maybe need delete non-system pod or drain will be hang .
#kubectl drain registr.dnion.com
#kubectl drain registr.dnion.com --ignore-daemonsets
#cat /var/lib/kubelet/cpu_manager_state
#rm -rf /var/lib/kubelet/cpu_manager_state
#vim /etc/sysconfig/kubelet
#kubectl get nodes
#1kubectl uncordon registr.dnion.com
#systemctl restart kubelet
#systemctl status kubelet
#journalctl -xe
#journalctl --help
#journalctl -xea
#journalctl --help
#journalctl -xea --no-tail
#journalctl -xea --no-tail -u
#journalctl -xea --no-tail
#journalctl -xea ---no-pager
#journalctl -xea --no-pager
#journalctl -xe --no-pager
#ubectl uncordon registr.dnion.com
#systemctl status system.slice
#
#systemctl restart kubelet


#ipvs ds confmap change and delete pod?
#modprobe ip_vs && modprobe ip_vs_rr && modprobe ip_vs_wrr && modprobe ip_vs_sh && modprobe nf_conntrack_ipv4

# container pod sysct config and static config
#cat /etc/sysconfig/kubelet
#KUBELET_EXTRA_ARGS=--allowed-unsafe-sysctls='net.ipv4.conf*' --cpu-manager-policy=static --kube-reserved=cpu=4000m  --kube-reserved-cgroup=/system.slice/kubelet.service --system-reserved=cpu=2000m --system-reserved-cgroup=/system.slice --enforce-node-allocatable=pods,kube-reserved,system-reserved
#KUBELET_EXTRA_ARGS=--allowed-unsafe-sysctls='net.ipv4.conf*' --cpu-manager-policy=static --kube-reserved=cpu=4000m --system-reserved=cpu=2000m
#KUBELET_EXTRA_ARGS=--allowed-unsafe-sysctls='net.ipv4.conf*' --cpu-manager-policy=static
#KUBELET_EXTRA_ARGS=--allowed-unsafe-sysctls='net.ipv4.conf*'

#ddns deploy
#git clone gitclone
#git clone https://github.com/inevity/k8smetal.git
pushd k8smetal/metallb
kubectl  apply -f metallb.yaml
kubectl   apply -f metallbarpcfgmap.yaml
#if registr.dnion.com not access,forbidden.
#use docker pull registr.dnion.com:5000/ddns:v1 (change the no_proxy of docker to including the hostname"
kubectl   apply -f metallb/ddnsdeploy.yaml
kubectl   apply -f  ddns-metal2iptableclusteronestaticip.yaml
popd


##flanel use vxlan to host-gw 
#[root@registr ddns]# git diff kube-flannel.yml
#diff --git a/kube-flannel.yml b/kube-flannel.yml
#index af1a9c6..a19feca 100644
#--- a/kube-flannel.yml
#+++ b/kube-flannel.yml
#@@ -75,7 +75,7 @@ data:
#     {
#       "Network": "10.244.0.0/16",
#       "Backend": {
#-        "Type": "vxlan"
#+        "Type": "host-gw"
#       }
#     }
# ---
#

#delete flannel ,and apply -f
# ingress upd explore







#apt-get install -y \
#     apt-transport-https \
#     ca-certificates \
#     curl \
#     gnupg2 \
#     software-properties-common \
#     gettext \
#     git
#
## docker install
#curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add -
#add-apt-repository \
#   "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
#   $(lsb_release -cs) \
#   stable"
#
#apt-get update
#
## pin docker release to 17.03.x (highest currently officially supported one)
#cat <<EOF > /etc/apt/preferences.d/docker-ce
#Package: docker-ce
#Pin: version 17.03.*
#Pin-Priority: 1000
#EOF
#
#apt-get install -y docker-ce
#
## disable swap (kubelet won't start with it)
#swapoff -a
#sed -i '/ swap / s/^/#/' /etc/fstab
#
## pin kubelet
#cat <<EOF > /etc/apt/preferences.d/kube
#Package: kubelet
#Pin: version 1.9.*
#Pin-Priority: 1000
#Package: kubeadm
#Pin: version 1.9.*
#Pin-Priority: 1000
#EOF
#
#curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
#cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
#deb http://apt.kubernetes.io/ kubernetes-xenial main
#EOF
#apt-get update
#apt-get install -y kubelet kubeadm kubectl

# ctrl+c maybe reset all set have apply
#trap ctrl_c INT
#
#function ctrl_c() {
#        cp -f /root/baul/html/ks.cfgbackup /root/baul/html/ks.cfg
#    }
#
