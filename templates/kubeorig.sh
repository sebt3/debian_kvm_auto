#!/bin/bash
#@DESC@ A kubernetes node unconfigured using officials repos

kb.install() {
	curl -s -L https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-alpha.0/crictl-v1.0.0-alpha.0-linux-amd64.tar.gz |tar zx -C "$MP/usr/bin"
	echo "net.bridge.bridge-nf-call-iptables=1" >"$MP/etc/sysctl.d/bridge.conf"
	echo "export KUBECONFIG=/etc/kubernetes/admin.conf">>"$MP/root/.bashrc"
	echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >"$MP/etc/apt/sources.list.d/kube.list"
	echo "deb https://download.docker.com/linux/debian buster stable" >"$MP/etc/apt/sources.list.d/docker.list"
	curl -s https://download.docker.com/linux/ubuntu/gpg | LANG=C chroot "$MP" apt-key add - 2>&1
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | LANG=C chroot "$MP" apt-key add - 2>&1
	LANG=C chroot "$MP" apt-get update 2>&1
	LANG=C chroot "$MP" apt-get install -y kubelet kubeadm kubectl docker-ce 2>&1
	LANG=C chroot "$MP" systemctl enable docker 2>&1
}

kb.base() {
	LANG=C chroot "$MP" apt-get install -y ca-certificates openjdk-8-jre-headless xvfb unzip libxi6 libgconf-2-4 2>&1
}
template.bootstrap() {
	create.bootstrap ",ca-certificates,gnupg2,ebtables,ethtool$1"
}
template.config() {
	[[ "$1" == "config" ]] && task.add kb.base "Download base packages for kubeadm"
	task.add kb.install		"install kubeadm"
}
