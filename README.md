# debian kvm auto
## Overview
This script automate the installation of kvm and libvirt on debian and the setup of debian based images.
It was meant to be able to play with kubernetes, so it have some feature around this.
There's no real magic in here as we're using the debian packages and debbootstrap, it's just nice to have it automated.

```
kvm_auto: Create debian VMs on a debian host with libvirt/KVM
./kvm_auto [-f|--file FILE] [-d|--disk DISK] [-m|--montpoint MP] [-r|--release RELEASE] [-M|--mirror MIRROR] [-E|--mem MEM] [-H|--hostname HNAME] [-p|--password PASS] [-v|--vlan VLAN] [-i|--last-ip LIP] [-t|--template TMPLT] [-a|--activity ACT] [-l|--list] [-b|--begin MIN] [-e|--end MAX] [-o|--only ONLY] [-h|--help]
./kvm_auto [ACT]
-f|--file FILE           : The image file               (DEFAULT: /root/default.qcow)
-d|--disk DISK           : The nbd device to use        (DEFAULT: /dev/nbd0)
-m|--montpoint MP        : Mount the image to           (DEFAULT: /tmp/images/default)
-r|--release RELEASE     : Debian release to use        (DEFAULT: sid)
-M|--mirror MIRROR       : Debian mirror                (DEFAULT: http://10.0.0.1:3142/debian)
-E|--mem MEM             : VM memory                    (DEFAULT: 524288)
-H|--hostname HNAME      : Hostname                     (DEFAULT: defaulthost)
-p|--password PASS       : root password                (DEFAULT: root)
-v|--vlan VLAN           : 3 first numbers of the vlan network            (DEFAULT: 10.0.0)
-i|--last-ip LIP         : last ip number for that vm in the vlan private (DEFAULT: 10)
-t|--template TMPLT      : Template to use for the initial configuration of the host
-a|--activity ACT        : Select the activity to run
-l|--list                : List all available tasks
-b|--begin MIN           : Begin at that task
-e|--end MAX             : End at that task
-o|--only ONLY           : Only run this step
-h|--help                : Show this help text

Available values for TMPLT (Template to use for the initial configuration of the host):
docker                   : A docker VM using the docker official repo
jenkins                  : A Jenkins server
kubemaster               : A kubernetes master
kubenode                 : A kubernetes node
kubeorig                 : A kubernetes node unconfigured using officials repos
selenium                 : A selenium instance

Available values for ACT (Select the activity to run):
uninstall                : Cleanup the configuration
setup                    : Setup the host system
create                   : Create a debian image
config                   : Configure an image
```

## Running instruction
For lisibility i'm using these 2 variables bellow :
```
    dka="path/to/kvm_auto"
    base="/path/to/images/root/"
```
Beside evrything is done by root...

### initial setup
This is going to install kvm and create a network for the VMs
```
    $dka setup
```

### create your first VM
```
    $dka -f $base/first.qcow -H first -i 2 -a create
```

### test kubernetes
Create a master kubernetes VM and 2 nodes and then reconfigure all of them so they know each others IPs
```
    $dka -a create -f $base/kubemaster.qcow -t kubemaster -H kubemaster -i 10 --mem 1048576
    $dka -a create -f $base/kube01.qcow     -t kubenode   -H kube01 -i 11
    rsync --info=progress2 $base/kube01.qcow $base/kube02.qcow
    $dka -a config -f $base/kube02.qcow     -H kube02 -i 12
    $dka -a config -f $base/kube01.qcow     -H kube01 -i 11
    $dka -a config -f $base/kubemaster.qcow -H kubemaster -i 10
```

Alternatively you could streamline the process by creating a node image that you clone and update later :
```
    $dka -a create -f $base/kube01.qcow     -H kube01 -i 11 -t kubenode
    rsync --info=progress2 $base/kube01.qcow $base/kubemaster.qcow
    rsync --info=progress2 $base/kube01.qcow $base/kube02.qcow
    $dka -a config -f $base/kube02.qcow     -H kube02 -i 12
    $dka -a config -f $base/kubemaster.qcow -H kubemaster -i 10 -t kubemaster --mem 1048576
    $dka -a config -f $base/kube02.qcow     -H kube02 -i 12
    $dka -a config -f $base/kube01.qcow     -H kube01 -i 11
```

And then configure your nodes :
```
    virsh start kubemaster
    ssh kubemaster
    # logout, that was just to accept the host key
    $dka -t kubemaster -a setupmaster -H kubemaster
    virsh destroy kubemaster
    virsh start kubemaster
    virsh start kube01
    virsh start kube02
```

### test docker swarm
Create the nodes. We'll use docker01 as master.
```
    $dka -t docker -a create       -f $base/docker01.qcow -H docker01 -i 31
    rsync --info=progress2 $base/docker01.qcow $base/docker02.qcow
    rsync --info=progress2 $base/docker02.qcow $base/docker03.qcow
    $dka -a config -f $base/docker02.qcow     -H docker02 -i 32
    $dka -a config -f $base/docker03.qcow     -H docker03 -i 33
    $dka -a config -f $base/docker02.qcow     -H docker02 -i 32
    $dka -a config -f $base/docker01.qcow     -H docker01 -i 31
    virsh start docker01
    virsh start docker02
    virsh start docker03
```
Then setup the swarm :
```
    ssh docker01 docker swarm init
    ssh docker02 $(ssh docker01 docker swarm join-token worker|grep join)
    ssh docker03 $(ssh docker01 docker swarm join-token worker|grep join)
```

## Managing your VM
Start:
```
    virsh start kubemaster
```
Connect to it:
```
    ssh kubemaster
```
Stop:
```
    virsh destroy kubemaster
```
