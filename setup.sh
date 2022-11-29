#!/bin/sh

# get url to latest latest release download available on github
# 
# usage:
#   gh_download_url [owner/repo] [filename-regex]
# 
# example:
#   gh_download_url "kubernetes-sigs/kustomize" "kustomize_.*_linux_amd64.tar.gz"
function gh_download_url() {
    curl -sL "https://api.github.com/repos/${1}/releases" | yq '[ .[] | .assets[] | select(.browser_download_url | match("'"${2}"'"))| .browser_download_url ] | .[0]'
}

# get architecture
case $(apk --print-arch) in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        echo "$(apk --print-arch) - not supported"
        exit 1
        ;;
esac

# fail on error and echo commands
set -xe

# install an update packages available to alpine
apk add -U bash git yq helm
apk add -t deps
apk add --update curl
apk del --purge deps
rm /var/cache/apk/*

mkdir -p /tmp/downloads

# install kustomize
KUSTOMIZE_DOWNLOAD_URL=$(gh_download_url "kubernetes-sigs/kustomize" "kustomize_.*_linux_${ARCH}.tar.gz")
curl -sL -o- "${KUSTOMIZE_DOWNLOAD_URL}" | tar -xzv -C /tmp/downloads
mv /tmp/downloads/kustomize /bin/kustomize
chmod +x /bin/kustomize

# install kubeconform
KUBECONFORM_DOWNLOAD_URL=$(gh_download_url "yannh/kubeconform" "kubeconform-linux-${ARCH}.tar.gz")
curl -sL -o- "${KUBECONFORM_DOWNLOAD_URL}" | tar -xzv -C /tmp/downloads
mv /tmp/downloads/kubeconform /bin/kubeconform
chmod +x /bin/kubeconform

rm -rf /tmp/downloads
