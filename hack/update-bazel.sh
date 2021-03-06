#!/usr/bin/env bash
# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
export KUBE_ROOT
source "${KUBE_ROOT}/hack/lib/init.sh"

# Ensure that we find the binaries we build before anything else.
export GOBIN="${KUBE_OUTPUT_BINPATH}"
PATH="${GOBIN}:${PATH}"

# Install tools we need, but only from vendor/...
go install k8s.io/kubernetes/vendor/github.com/bazelbuild/bazel-gazelle/cmd/gazelle
go install k8s.io/kubernetes/vendor/github.com/bazelbuild/buildtools/buildozer
go install k8s.io/kubernetes/vendor/k8s.io/repo-infra/kazel

touch "${KUBE_ROOT}/vendor/BUILD"
# Ensure that we use the correct importmap for all vendored dependencies.
# Probably not necessary in gazelle 0.13+
# (https://github.com/bazelbuild/bazel-gazelle/pull/207).
if ! grep -q "# gazelle:importmap_prefix" "${KUBE_ROOT}/vendor/BUILD"; then
  echo "# gazelle:importmap_prefix k8s.io/kubernetes/vendor" >> "${KUBE_ROOT}/vendor/BUILD"
fi

gazelle fix \
    -external=vendored \
    -mode=fix \
    -repo_root "${KUBE_ROOT}" \
    "${KUBE_ROOT}"

kazel

# make targets in vendor manual
# buildozer exits 3 when no changes are made ¯\_(ツ)_/¯
# https://github.com/bazelbuild/buildtools/tree/master/buildozer#error-code
buildozer -quiet 'add tags manual' '//vendor/...:%go_binary' '//vendor/...:%go_test' && ret=$? || ret=$?
if [[ $ret != 0 && $ret != 3 ]]; then
  exit 1
fi
