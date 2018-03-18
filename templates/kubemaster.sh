#!/bin/bash
#@DESC@ A kubernetes master
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

. "${TEMPLATE_DIR}/kubenode.sh"

kbm.enable.verify() { task.verify.permissive; }
kbm.enable() {
	LANG=C chroot "$MP" systemctl enable etcd
	LANG=C chroot "$MP" systemctl enable flannel
	LANG=C chroot "$MP" systemctl enable docker
	LANG=C chroot "$MP" systemctl enable kube-apiserver
	LANG=C chroot "$MP" systemctl enable kube-controller-manager
	LANG=C chroot "$MP" systemctl enable kubelet
	LANG=C chroot "$MP" systemctl enable kube-proxy
	LANG=C chroot "$MP" systemctl enable kube-scheduler
}

kbm.etcd.verify() { task.verify.permissive; }
kbm.etcd() {
	cat >"$MP/etc/default/etcd" <<ENDCFG
DAEMON_ARGS=--advertise-client-urls http://${VLAN}.$LIP:4001 --listen-client-urls http://${VLAN}.$LIP:4001,http://127.0.0.1:4001
ENDCFG
	LANG=C chroot "$MP" systemctl enable etcd
}
kbm.kubelet.verify() { task.verify.permissive; }
kbm.kubelet() {
	kbn.kubelet "--register-schedulable=false"
	sed -i 's/^After.*service/After=docker.service flannel.service kube-apiserver.service/' "$MP/lib/systemd/system/kubelet.service"
}
kbm.apiserver.verify() { task.verify.permissive; }
kbm.apiserver() {
	mkdir -p "$MP/var/lib/kubernetes/crt"
	chroot "$MP" chown kube:kube /var/lib/kubernetes/crt /var/lib/kubernetes
	if [ ! -f "$MP/var/lib/kubernetes/kube-serviceaccount.key" ]; then
		openssl genrsa -out "$MP/var/lib/kubernetes/kube-serviceaccount.key" 2048 2>/dev/null
	fi
	chroot "$MP" chown kube:kube /var/lib/kubernetes/kube-serviceaccount.key
	sed -i 's/^After.*service/After=etcd.service flannel.service/' "$MP/lib/systemd/system/kube-apiserver.service"
	cat >"$MP/etc/default/kube-apiserver" <<ENDCFG
KUBE_API_ADDRESS="--insecure-bind-address=0.0.0.0 --insecure-port=8080 --bind-address=0.0.0.0 --advertise_address=${VLAN}.$LIP"
KUBE_ETCD_SERVERS="--etcd-servers=http://${VLAN}.$LIP:4001"
KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota"
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=192.168.0.0/16"
DAEMON_ARGS="--cert-dir=/var/lib/kubernetes/crt --service-account-key-file=/var/lib/kubernetes/kube-serviceaccount.key --service-account-lookup=false"
ENDCFG
	LANG=C chroot "$MP" systemctl enable kube-apiserver
}
kbm.control.verify() { task.verify.permissive; }
kbm.control() {
	sed -i 's/^After.*/After=network.target kube-apiserver.service/' "$MP/lib/systemd/system/kube-controller-manager.service"
	cat >"$MP/etc/default/kube-controller-manager" <<ENDCFG
DAEMON_ARGS="--service-account-private-key-file=/var/lib/kubernetes/kube-serviceaccount.key --root-ca-file=/var/lib/kubernetes/crt/apiserver.crt --enable-hostpath-provisioner=false --pvclaimbinder-sync-period=15s --master=${VLAN}.$MIP:8080"
ENDCFG
	LANG=C chroot "$MP" systemctl enable kube-controller-manager
}
kbm.proxy.verify() { task.verify.permissive; }
kbm.proxy() {
	kbn.proxy
	sed -i 's/^After.*/After=network.target kube-apiserver.service/' "$MP/lib/systemd/system/kube-proxy.service"
}

kbm.scheduler.verify() { task.verify.permissive; }
kbm.scheduler() {
	cat >"$MP/etc/default/kube-scheduler" <<ENDCFG
KUBE_MASTER=--master=http://${VLAN}.$MIP:8080
DAEMON_ARGS=""
ENDCFG
	sed -i 's/^After.*/After=network.target kube-apiserver.service/' "$MP/lib/systemd/system/kube-scheduler.service"
	LANG=C chroot "$MP" systemctl enable kube-scheduler
}

kbm.install.verify() { task.verify.permissive; }
kbm.install() {
	kbn.install kubernetes-master etcd-server
}

template.bootstrap() {
	kbn.bootstrap ",etcd-server,kubernetes-master"
}
template.config() {
	[[ "$1" == "config" ]] && task.add kbm.install "Download base packages for a Kubernetes master"
	task.add kbm.etcd		"Enable etcd"
	task.add kbn.flannel		"Enable flannel"
	task.add kbn.docker		"Configure docker to use flannel"
	task.add kbm.apiserver		"Configure kubernetes apiserver"
	task.add kbm.control		"Configure kubernetes control-manager"
	task.add kbm.kubelet		"Configure kubernetes kubelet"
	task.add kbm.proxy		"Configure kubernetes proxy"
	task.add kbm.scheduler		"Configure kubernetes scheduler"
}



setupm.confnet() {
	ssh -q -o PasswordAuthentication=no "$HNAME" "etcdctl set /coreos.com/network/config '{ \"Network\": \"${VLAN}.0/16\" }'"
}
setupmaster() {
	task.add setupm.confnet		"Configure etcd"
}
act.add.post setupmaster "Configure a running VM for kubernetes master usage"


