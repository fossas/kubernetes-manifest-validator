#!/bin/bash
set -e

# remember root path
ROOT_PATH=$(realpath .)

# resolve chart directory from pre-fetch dir
[ -z "${2}" ] || CHART_DIR_PATH="${ROOT_PATH}/${2}"
[ -z "${2}" ] || CHARTS_ARE_PRE_FETCHED="true"
# fall back to a tempdir
[ -z "${2}" ] && CHART_DIR_PATH=$(mktemp -d)


# change working directory to where manifests reside
cd "${1:-${PWD}}"
echo "Using ${PWD}"

# don't blindly overwrite files, that's bad
if [ -f kustomization.yaml ]; then
    echo "kustomization.yaml exists, perhaps script cleanup failed during prior run"
    exit 1
fi

# temp directory for files
TMP=$(mktemp -d)

MANIFEST_YAML="${TMP}/manifest.yaml"

# ensure cleanup of kustomization.yaml and  temp directory
trap "rm -rf ${TMP} kustomization.yaml" EXIT

echo "Finding resources in ${PWD}"
RESOURCES=$(find . -path '*.yaml' | grep -v 'kustomization.yaml' | grep -v '.github' | paste -s -d ',' -)

echo "Generating kustomization.yaml"
kustomize create --resources "${RESOURCES}"

echo "Building manifest from kustomization.yaml"
kustomize build > "${MANIFEST_YAML}"

echo "Validating manifests with kubeconform"
cat "${MANIFEST_YAML}" | kubeconform -ignore-missing-schemas

echo "Validating helm.fluxcd.io/v1 HelmReleases via HelmTemplate commands"
yq 'select(.apiVersion == "helm.fluxcd.io/v1") | select(.kind == "HelmRelease") | (["HR_NAMESPACE="+.metadata.namespace, "HR_NAME="+.metadata.name] | join(" "))' "${MANIFEST_YAML}" | sort | uniq | grep -vE '^\-\-\-$|^$' \
| while IFS='' read -r LINE; do
    eval "${LINE}"

    HR="${HR_NAMESPACE}/${HR_NAME}"
    HR_MANIFEST="${TMP}/HelmRelease-${HR_NAMESPACE}-${HR_NAME}.yaml"
    HR_VALUES="${TMP}/HelmRelease-${HR_NAMESPACE}-${HR_NAME}.values.yaml"

    echo "Gathering HelmRelease manifest of ${HR}"
    yq 'select(.apiVersion == "helm.fluxcd.io/v1") | select(.kind == "HelmRelease")
        | select(.metadata.namespace == "'"${HR_NAMESPACE}"'")
        | select(.metadata.name == "'"${HR_NAME}"'") | .' "${MANIFEST_YAML}" > "${HR_MANIFEST}"
    
    echo "Gathering HelmRelease values for ${HR}"
    yq '.spec.values' "${HR_MANIFEST}" > "${HR_VALUES}"
    
    RELEASE_NAME=$(yq '.spec.releaseName // .metadata.name' "${HR_MANIFEST}")
    RELEASE_NAMESPACE=$(yq '.spec.targetNamespace // .metadata.namespace' "${HR_MANIFEST}")
    
    RELEASE_CHART_REPOSITORY=$(yq '.spec.chart.repository // ""' "${HR_MANIFEST}")
    RELEASE_CHART_NAME=$(yq '.spec.chart.name // ""' "${HR_MANIFEST}")
    RELEASE_CHART_VERSION=$(yq '.spec.chart.version // ""' "${HR_MANIFEST}")

    RELEASE_CHART_GIT=$(yq '.spec.chart.git // ""' "${HR_MANIFEST}")
    RELEASE_CHART_REF=$(yq '.spec.chart.ref // ""' "${HR_MANIFEST}")
    RELEASE_CHART_PATH=$(yq '.spec.chart.path // ""' "${HR_MANIFEST}")

    if [ "${RELEASE_CHART_REPOSITORY}" != "" ]; then
        echo "Running helm template command for ${HR} with values"
        helm template --release-name "${RELEASE_NAME}" "${RELEASE_CHART_NAME}" --version "${RELEASE_CHART_VERSION}" --namespace "${RELEASE_NAMESPACE}" --repo "${RELEASE_CHART_REPOSITORY}" --values "${HR_VALUES}" > /dev/null
    elif [ "${RELEASE_CHART_GIT}" != "" ]; then
        CHART_DIR="${CHART_DIR_PATH}/${RELEASE_NAMESPACE}/${RELEASE_NAME}"
        
        # assuming this is not a github action, cloning the repo manually is required
        if [ -z "${CHARTS_ARE_PRE_FETCHED}" ]; then
            mkdir -p "${CHART_DIR}"
            echo "Cloning ${RELEASE_CHART_GIT}"
            git clone "${RELEASE_CHART_GIT}" "${CHART_DIR}"
        fi

        # confirm it was prefetched
        if [ ! -d "${CHART_DIR}" ]; then
            echo "ERROR: Failed to find chart for ${HR} in ${CHART_PATH}"
            echo "Hint: This should be pre-fetched with actions/checkout"
            exit 1
        fi

        cd "${CHART_DIR}"

        echo "Adding git config safe.directory for ${CHART_DIR}"
        git config --global --add safe.directory "${CHART_DIR}"

        echo "Checking out ${RELEASE_CHART_REF}"
        git checkout "${RELEASE_CHART_REF}"

        echo "Building dependencies for ${RELEASE_CHART_PATH}"
        helm dependency update "${RELEASE_CHART_PATH}"

        echo "Running helm template command for ${HR} with values"
        helm template --release-name "${RELEASE_NAME}" "${RELEASE_CHART_PATH}" --version "${RELEASE_CHART_VERSION}" --namespace "${RELEASE_NAMESPACE}" --repo "${RELEASE_CHART_REPOSITORY}" --values "${HR_VALUES}" > /dev/null
        cd -
    else
        echo "ERROR: HelmRelease must have .spec.chart.repository or .spec.chart.git set."
        exit 1
    fi

done

echo "Validation completed without errors."
