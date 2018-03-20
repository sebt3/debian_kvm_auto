#!/bin/bash
#@DESC@ A kubernetes node unconfigured using officials repos
# BSD 3-Clause License
# 
# Copyright (c) 2018, Sébastien Huss
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

MASTER=${MASTER:-"kubemaster"}
args.declare MASTER   -A --master  Vals NoOption NotMandatory "Master hostname		(DEFAULT: $MASTER)"

kb.install.verify() { task.verify.permissive; }
kb.install() {
	curl -s -L https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-alpha.0/crictl-v1.0.0-alpha.0-linux-amd64.tar.gz |tar zx -C "$MP/usr/bin"
	echo "net.bridge.bridge-nf-call-iptables=1" >"$MP/etc/sysctl.d/bridge.conf"
	echo "export KUBECONFIG=/etc/kubernetes/admin.conf">>"$MP/root/.bashrc"
	echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >"$MP/etc/apt/sources.list.d/kube.list"
	echo "deb https://download.docker.com/linux/debian buster stable" >"$MP/etc/apt/sources.list.d/docker.list"
	curl -s https://download.docker.com/linux/ubuntu/gpg | LANG=C chroot "$MP" apt-key add -
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | LANG=C chroot "$MP" apt-key add -
	LANG=C chroot "$MP" apt-get update
	LANG=C chroot "$MP" apt-get install -y kubelet kubeadm kubectl docker-ce
	LANG=C chroot "$MP" systemctl enable docker
}
kb.bridge() {
	echo "net.bridge.bridge-nf-call-iptables=1" >"$MP/etc/sysctl.d/bridge.conf"
	#sysctl -fa 2>/dev/null |grep bridge-nf-call-iptables
}

kb.base.verify() { task.verify.permissive; }
kb.base() {
	LANG=C chroot "$MP" apt-get install -y ca-certificates gnupg2 ebtables ethtool
}
template.bootstrap() {
	create.bootstrap ",ca-certificates,gnupg2,ebtables,ethtool$1"
}
template.config() {
	[[ "$1" == "config" ]] && task.add kb.base "Download base packages for kubeadm"
	task.add kb.install		"install kubeadm"
	task.add kb.bridge		"configure the kernel for bridge"
}

############################
####
##  Custom activities
#
setupm.init() {
	ssh -q -o PasswordAuthentication=no "$HNAME" kubeadm init "--apiserver-advertise-address=${VIP}.$LIP" "--pod-network-cidr=10.244.0.0/16" --ignore-preflight-errors=all
}

setupm.enable.verify() { task.verify.permissive; }
setupm.enable() {
	ssh -q -o PasswordAuthentication=no "$HNAME" systemctl enable kubelet
	ssh -q -o PasswordAuthentication=no "$HNAME" systemctl start kubelet
}
setupm.flannel() {
	ssh -q -o PasswordAuthentication=no "$HNAME" kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml
}
setupmaster() {
	task.add setupm.init		"Initialize the kube infrastructure"
	task.add setupm.enable		"Start the kubelet"
	task.add setupm.flannel		"Start the flannel"
}
act.add.post setupmaster "Configure a running VM for kubernetes master usage"

setupn.init() {
	# TODO: find a way to get theses keys from the master
	#ssh -q -o PasswordAuthentication=no "$HNAME" kubeadm join --token 6cabd8.2b97af7e9335116f 10.0.0.10:6443 --discovery-token-ca-cert-hash sha256:28a04bebf81bd0e711ec167411c20a29f3bbd8ef7cebc8385f9c9e3e108b5599 --ignore-preflight-errors=all
	:
}
setupnode() {
	task.add setupn.init		"Initialize the kube infrastructure"
}
act.add.post setupnode "Configure a running VM for kubernetes node usage"

