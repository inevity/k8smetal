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

