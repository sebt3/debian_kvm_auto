#!/bin/bash
#@DESC@ A selenium instance

sele.lastversion() {
	curl -s http://selenium-release.storage.googleapis.com/|xpath -e ListBucketResult/Contents/Key 2>/dev/null |awk '/selenium-server-standalone/&&/Key/&&!/beta/{gsub(".*-","");gsub(".jar.*","");print}'|sort -t. -k 1,1n -k 2,2n -k 3,3n|tail -1
}

sele.download() {
	local V=$(sele.lastversion)
	local s=$(awk -F. '{print $1"."$2}'<<<$V)
	mkdir -p "$MP/opt/selenium"
	curl -s -o "$MP/opt/selenium/selenium.jar" http://selenium-release.storage.googleapis.com/${s}/selenium-server-standalone-${V}.jar
}

sele.firefox() {
	LANG=C chroot "$MP" apt-get install -y firefox 2>&1
}

sele.base() {
	LANG=C chroot "$MP" apt-get install -y ca-certificates openjdk-8-jre-headless xvfb unzip libxi6 libgconf-2-4 2>&1
}

template.bootstrap() {
	create.bootstrap ",ca-certificates,openjdk-8-jre-headless,xvfb,unzip,libxi6,libgconf-2-4"
}
template.config() {
	[[ "$1" == "config" ]] && task.add sele.base "Download base packages for Selenium"
	task.add sele.download		"Download Selenium"
	task.add sele.firefox		"Install firefox"
}
