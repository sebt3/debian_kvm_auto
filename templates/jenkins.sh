#!/bin/bash
#@DESC@ A Jenkins server

jk.install() {
	echo "deb https://pkg.jenkins.io/debian binary/" >"$MP/etc/apt/sources.list.d/jenkins.list"
	curl -s https://pkg.jenkins.io/debian/jenkins.io.key | LANG=C chroot "$MP" apt-key add - 2>&1
	LANG=C chroot "$MP" apt-get update 2>&1
	LANG=C chroot "$MP" apt-get install -y jenkins 2>&1
	LANG=C chroot "$MP" systemctl enable jenkins 2>&1
}

jk.base() {
	LANG=C chroot "$MP" apt-get install -y ca-certificates openjdk-8-jre-headless gnupg2 2>&1
}
template.bootstrap() {
	create.bootstrap ",ca-certificates,openjdk-8-jre-headless,gnupg2"
}
template.config() {
	[[ "$1" == "config" ]] && task.add jk.base "Download base packages for jenkins"
	task.add jk.install		"install jenkins"
}
