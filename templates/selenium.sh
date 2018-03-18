#!/bin/bash
#@DESC@ A selenium instance
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
