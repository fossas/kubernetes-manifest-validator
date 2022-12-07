# Manifest Validator
A container and GitHub action to validate Kubernetes Manifests.


## Validating Manifests Locally
Simply run the provided container like this to do local validation. SSH keys are only necessary if fetching additional repos is necessary to validate helm charts.
```
docker run --rm -it \
  -v "${PWD}:/workdir" -w /workdir \
  -v "${HOME}/.ssh:/home/runner/.ssh" \
  ghcr.io/protosam/kubernetes-manifest-validator:latest PATH_TO_VALIDATE [PRE_FETCHED_HELM_CHARTS_PATH]
```

## Usage
```yaml
name: Deployment Validation
on: push
jobs:
  test:
    name: Verify Values
    runs-on: ubuntu-latest
    steps:
      # fetch local repository
      - name: Checkout owner/repo
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      # fetch repository containing charts for HelmReleases requiring git
      - name: Checkout owner/repo for HelmRelease <target-namespace>/<release-name>
        uses: actions/checkout@v3
        with:
          ssh-key: ${{ secrets.SSH_KEY }}
          path: "chart_repos/<target-namespace>/<release-name>"
          fetch-depth: 0
          repository: "<owner>/<repo>"
      
      - name: Validate manifests
        uses: protosam/kubernetes-manifest-validator@master
        with:
          # directory in repo to validate manifests from
          path: "."
          # directory containing pre-fetched charts from git repositories
          chartReposPath: "chart_repos"
```

## Building Locally
```
docker build -t ghcr.io/protosam/kubernetes-manifest-validator:latest .
```
