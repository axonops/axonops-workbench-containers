---
name: Build Containers

on:
  push:
    branches:
      - initial
    # tags:
    #   - 'v*'

defaults:
  run:
    shell: bash

jobs:
  prepare:
    name: Get Cassandra versions
    runs-on: ubuntu-latest
    outputs:
      versions50: ${{ steps.cassandra_versions.outputs.versions50 }}
      versions40: ${{ steps.cassandra_versions.outputs.versions40 }}
      versions41: ${{ steps.cassandra_versions.outputs.versions41 }}
    steps:
      - name: Get versions
        id: cassandra_versions
        run: |
          archive_url="https://archive.apache.org/dist/cassandra/"
          url="https://downloads.apache.org/cassandra/"

          # Use curl to fetch the HTML content and grep to filter 4.x versions
          versions40=$(curl -s $archive_url | grep -E '4\.0\.[0-9]+/' | awk '{print $5}'|cut -d \> -f2 | sed 's$/</a$$g' | sort | jq -R -c -s 'split("\n")[:-1]')
          versions41=$(curl -s $archive_url | grep -E '4\.1\.[0-9]+/' | awk '{print $5}'|cut -d \> -f2 | sed 's$/</a$$g' | sort | jq -R -c -s 'split("\n")[:-1]')
          versions50=$(curl -s $archive_url | grep -E '5\.0\.[0-9]+/' | awk '{print $5}'|cut -d \> -f2 | sed 's$/</a$$g' | sort | jq -R -c -s 'split("\n")[:-1]')

          all_versions=$(jq -c -n --argjson "5.0" $versions50 --argjson "4.0" $versions40 --argjson "4.1" $versions41 '$ARGS.named')

          delimiter="$(openssl rand -hex 8)"
          echo "versions50<<${delimiter}" >> "${GITHUB_OUTPUT}"
          echo "$versions50" >> "${GITHUB_OUTPUT}"
          echo "${delimiter}" >> "${GITHUB_OUTPUT}"

          delimiter="$(openssl rand -hex 8)"
          echo "versions41<<${delimiter}" >> "${GITHUB_OUTPUT}"
          echo "$versions41" >> "${GITHUB_OUTPUT}"
          echo "${delimiter}" >> "${GITHUB_OUTPUT}"

          delimiter="$(openssl rand -hex 8)"
          echo "versions40<<${delimiter}" >> "${GITHUB_OUTPUT}"
          echo "$versions40" >> "${GITHUB_OUTPUT}"
          echo "${delimiter}" >> "${GITHUB_OUTPUT}"

          delimiter="$(openssl rand -hex 8)"
          echo "all_versions<<${delimiter}" >> "${GITHUB_OUTPUT}"
          echo "$all_versions" >> "${GITHUB_OUTPUT}"
          echo "${delimiter}" >> "${GITHUB_OUTPUT}"

      - run: echo '${{ steps.cassandra_versions.outputs.versions50 }}' | jq -r .

  build50:
    name: Build containers for Cassandra 5.0
    runs-on: ubuntu-latest
    needs: [prepare]
    strategy:
      matrix:
        version: ${{ fromJSON(needs.prepare.outputs.versions50) }}
    steps: &docker_steps
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: "Get docker info"
        run: |
          echo "Actor: ${{ github.actor }}"
          echo "REPO_OWNER=$(echo ${{ github.repository_owner }} | tr '[:upper:]' '[:lower:]')" >> $GITHUB_ENV

      - name: "Log into GitHub Container Registry"
        if: "github.event_name != 'pull_request'"
        uses: "docker/login-action@v1"
        with:
          registry: "ghcr.io"
          username: "${{ github.actor }}"
          password: "${{ secrets.GITHUB_TOKEN }}"

      - name: Prepare AxonOps Workbench Dockerfile
        id: setup
        run: |
          CASSANDRA_SHA512=$(curl -L --connect-timeout 2 --retry 5 --retry-delay 1 https://archive.apache.org/dist/cassandra/${{ matrix.version }}/apache-cassandra-${{ matrix.version }}-bin.tar.gz.sha512)
          echo "CASSANDRA_SHA512=$CASSANDRA_SHA512" >> $GITHUB_ENV

          CASSANDRA_VERSION=${{ matrix.version }}
          MAJOR_VERSION="${CASSANDRA_VERSION%.*}"
          echo "MAJOR_VERSION=$MAJOR_VERSION" >> $GITHUB_ENV

          echo "CASSANDRA_VERSION=${{ matrix.version }}" >> $GITHUB_ENV

          cp axonops-entrypoint.sh cassandra/${MAJOR_VERSION}

          sed -i "s/ENV CASSANDRA_VERSION.*/ENV CASSANDRA_VERSION ${{ matrix.version }}/g" cassandra/${MAJOR_VERSION}/Dockerfile
          sed -i "s/ENV CASSANDRA_SHA512.*/ENV CASSANDRA_SHA512 $CASSANDRA_SHA512/g" cassandra/${MAJOR_VERSION}/Dockerfile

          echo "context=cassandra/$MAJOR_VERSION" >> $GITHUB_OUTPUT
          echo "CASSANDRA_VERSION=$CASSANDRA_VERSION" >> $GITHUB_OUTPUT
          echo "MAJOR_VERSION=$MAJOR_VERSION" >> $GITHUB_OUTPUT

      # - name: Build the Apache Cassandra image
      #   uses: docker/build-push-action@v4
      #   id: build
      #   with:
      #     platforms: linux/amd64,linux/arm64
      #     build-args: |
      #       VERSION=${{ matrix.version }}
      #       GitCommit=${{ github.sha }}
      #       MAJOR_VERSION=${{ env.MAJOR_VERSION }}
      #     context: ${{ steps.setup.outputs.context }}
      #     push: true
      #     file: ${{ steps.setup.outputs.context }}/Dockerfile
      #     tags: |
      #       ghcr.io/${{ env.REPO_OWNER }}/cassandra:${{ steps.setup.outputs.CASSANDRA_VERSION }}
      #     labels: |
      #       LABEL org.opencontainers.image.source="https://github.com/${{ env.REPO_OWNER }}/axonops-workbench-containers"

      - name: Generate manitest
        run: |
          set -x

          mkdir -p manifests/cassandra/docker

          REPO=ghcr.io/${{ env.REPO_OWNER }}/cassandra:${{ matrix.version }}

          jq -n \
            --argjson "${{ env.MAJOR_VERSION }}" "$(jq -n --arg digest '${{ steps.build.outputs.digest }}' --arg tag '${{ steps.setup.outputs.CASSANDRA_VERSION }}' --arg repo "$REPO" '$ARGS.named')" \
            '$ARGS.named' > manifests/cassandra/docker/${{ matrix.version }}.json
      - name: Commit manifest
        run: |
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          git add manifests
          git commit -m "Add manifest"

      - name: Push changes
        uses: ad-m/github-push-action@master
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          branch: ${{ github.ref }}

  build41:
    name: Build containers for Cassandra 4.0
    runs-on: ubuntu-latest
    needs: [prepare]
    strategy:
      matrix:
        version: ${{ fromJSON(needs.prepare.outputs.versions41) }}
    steps: *docker_steps

  build40:
    name: Build containers for Cassandra 4.1
    runs-on: ubuntu-latest
    needs: [prepare]
    strategy:
      matrix:
        version: ${{ fromJSON(needs.prepare.outputs.versions40) }}
    steps: *docker_steps

      # - name: Generate manitest
      #   run: |
      #     set -x
      #     REPO5=ghcr.io/${{ env.REPO_OWNER }}/cassandra:${{ steps.versions.outputs.CASS5_VERSION }}
      #     REPO41=ghcr.io/${{ env.REPO_OWNER }}/cassandra:${{ env.CASS41_VERSION }}
      #     REPO4=ghcr.io/${{ env.REPO_OWNER }}/cassandra:${{ env.CASS4_VERSION }}

      #     jq -n \
      #       --argjson "${{ env.CASS5_VERSION }}" "$(jq -n --arg digest '${{ steps.build5.outputs.digest }}' --arg tag '${{ steps.versions.outputs.CASS5_VERSION }}' --arg repo "$REPO5" '$ARGS.named')" \
      #       --argjson "${{ env.CASS41_VERSION }}" "$(jq -n --arg digest '${{ steps.build41.outputs.digest }}' --arg tag '${{ env.CASS41_VERSION }}' --arg repo "$REPO41" '$ARGS.named')" \
      #       --argjson "${{ env.CASS4_VERSION }}" "$(jq -n --arg digest '${{ steps.build4.outputs.digest }}' --arg tag '${{ env.CASS4_VERSION }}' --arg repo "$REPO4" '$ARGS.named')" \
      #       '$ARGS.named' > manifest.json

      # - name: Commit manifest.json
      #   run: |
      #     git config --local user.email "github-actions[bot]@users.noreply.github.com"
      #     git config --local user.name "github-actions[bot]"
      #     git add manifest.json
      #     git commit -m "Add manifest"

      # - name: Push changes
      #   uses: ad-m/github-push-action@master
      #   with:
      #     github_token: ${{ secrets.GITHUB_TOKEN }}
      #     branch: ${{ github.ref }}
