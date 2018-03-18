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
