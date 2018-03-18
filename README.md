# debian kvm auto
## Overview
This script automate the installation of kvm and libvirt on debian and the setup of debian based images.
It was meant to be able to play with kubernetes, so it have some feature around this.
There's no real magic in here as we're using the debian packages and debbootstrap, it's just nice to have it automated.

## Running instruction
For lisibility i'm using these 2 variables bellow :
    dka="path/to/kvm_auto"
    base="/path/to/images/root/"
Beside evrything is done by root...

### initial setup
This is going to install kvm and create a network for the VMs
    $dka setup

### create your first VM
    $dka -f $base/first.qcow -H first -I 2 -a create

### test kubernetes
Create a master kubernetes VM and 2 nodes and then reconfigure all of them so they know each others IPs
    $dka -a create -f $base/kubemaster.qcow -t kubemaster -H kubemaster -I 10 --mem 1048576
    $dka -a create -f $base/kube01.qcow     -t kubenode   -H kube01 -I 11
    cp $base/kube01.qcow $base/kube02.qcow
    $dka -a config -f $base/kube02.qcow     -H kube02 -I 12
    $dka -a config -f $base/kube01.qcow     -H kube01 -I 11
    $dka -a config -f $base/kubemaster.qcow -H kubemaster -I 10

Alternatively you could streamline the process by creating a node image that you clone and update later :
    $dka -a create -f $base/kube01.qcow     -H kube01 -I 11 -t kubenode
    cp $base/kube01.qcow $base/kubemaster.qcow
    cp $base/kube01.qcow $base/kube02.qcow
    $dka -a config -f $base/kube02.qcow     -H kube02 -I 12
    $dka -a config -f $base/kubemaster.qcow -H kubemaster -I 10 -t kubemaster --mem 1048576
    $dka -a config -f $base/kube02.qcow     -H kube02 -I 12
    $dka -a config -f $base/kube01.qcow     -H kube01 -I 11

And then configure your nodes :
    virsh start kubemaster
    ssh kubemaster
    # logout, that was just to accept the host key
    $dka -a setupmaster -H kubemaster
    virsh destroy kubemaster
    virsh start kubemaster
    virsh start kube01
    virsh start kube02

## Managing your VM
Start:
    virsh start kubemaster
Connect to it:
    ssh kubemaster
Stop:
    virsh destroy kubemaster
