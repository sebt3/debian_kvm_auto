#!/bin/bash
#@DESC@ A kubernetes node
#########################################################################################################
### Kubernetes stuff
kbn.getcri() {
	curl -q https://storage.googleapis.com/cri-containerd-release/cri-containerd-${CRIVERS}.linux-amd64.tar.gz 2>/dev/null |tar xzf - -C "$MP"
}
kbn.flannel() {
	mkdir -p "$MP/var/lib/flannel"
	cat >"$MP/lib/systemd/system/flannel.service" <<ENDCFG
[Unit]
Description=Network fabric for containers
Documentation=https://github.com/coreos/flannel
After=etcd.service

[Service]
Type=notify
Restart=always
RestartSec=5
ExecStart=/usr/bin/flannel -etcd-endpoints=http://${VLAN}.$MIP:4001 -subnet-file=/var/lib/flannel/subnet.env

[Install]
WantedBy=multi-user.target
ENDCFG
	LANG=C chroot "$MP" systemctl enable flannel 2>&1
}

kbn.docker() {
	cat >"$MP/lib/systemd/system/docker.service" <<ENDCFG
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target docker.socket firewalld.service flannel.service
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
EnvironmentFile=-/var/lib/flannel/subnet.env
ExecStart=/usr/sbin/dockerd -H fd:// --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=1048576
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process

[Install]
WantedBy=multi-user.target
ENDCFG
	LANG=C chroot "$MP" systemctl enable docker 2>&1
}
kbn.kubelet() {
	mkdir -p "$MP/var/lib/kubernetes"
	sed -i 's/^After.*service/After=docker.service flannel.service/' "$MP/lib/systemd/system/kubelet.service"
	cat >"$MP/etc/default/kubelet" <<ENDCFG
# KUBELET_ADDRESS="--address=127.0.0.1"
# KUBELET_PORT="--port=10250"
# KUBELET_HOSTNAME="--hostname-override=127.0.0.1"
KUBELET_API_SERVER="--api-servers=${VLAN}.$MIP:8080"
DAEMON_ARGS="--cert-dir=/var/lib/kubernetes/ --chaos-chance=0.0 --container-runtime=docker $1 --address=0.0.0.0 --cpu-cfs-quota=false  --cluster-dns=8.8.8.8"
ENDCFG
	LANG=C chroot "$MP" systemctl enable kubelet 2>&1
}
kbn.proxy() {
	cat >"$MP/etc/default/kube-proxy" <<ENDCFG
KUBE_MASTER=--master=http://${VLAN}.$MIP:8080
DAEMON_ARGS=""
ENDCFG
	sed -i 's/^After.*/After=network.target flannel.service/' "$MP/lib/systemd/system/kube-proxy.service"
	LANG=C chroot "$MP" systemctl enable kube-proxy 2>&1
}

kbn.install() {
	#containerd libseccomp2 libapparmor1
	LANG=C chroot "$MP" apt-get install -y ca-certificates etcd-client flannel kubernetes-node kubernetes-client "$@"
}
kbn.bootstrap() {
	create.bootstrap ",ca-certificates,kubernetes-client,kubernetes-node,etcd-client,flannel$1"
}


template.bootstrap() {
	kbn.bootstrap
}
template.config() {
	[[ "$1" == "config" ]] && task.add kbn.install "Download base packages for a Kubernetes node"
	task.add kbn.flannel		"Enable flannel"
	task.add kbn.docker		"Configure docker to use flannel"
	task.add kbn.proxy		"Configure kubernetes proxy"
	task.add kbn.kubelet		"Configure kubernetes kubelet"
}
