#!/bin/bash
#@DESC@ A Jenkins server
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
