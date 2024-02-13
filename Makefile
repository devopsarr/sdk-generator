APP ?= prowlarr
SDK ?= py
URL ?= https://raw.githubusercontent.com/Prowlarr/Prowlarr/7e32b54547a18fcf896cc12249533894c927ccd0/src/Prowlarr.Api.V1/openapi.json
VERSION ?= 0.6.0
OPENAPI_GENERATOR_IMAGE ?= openapitools/openapi-generator-cli:v7.3.0@sha256:74b9992692c836e42a02980db4b76bee94e17075e4487cd80f5c540dd57126b9
BASE_PATH ?= .generated-code/${APP}-${SDK}
PY_VERSION_FILES ?= setup.py pyproject.toml ${APP}/__init__.py ${APP}/api_client.py

get-swagger:
	mkdir swaggers || true
	curl ${URL} | yq -P -o json > ./swaggers/${APP}.json

var-generation:
	mkdir vars || true
	sed "s/servarr/${APP}/gI; s/0.0.1/${VERSION}/gI" templates/${SDK}/vars.yaml > vars/${APP}-${SDK}.yaml

git-init:
	cd ${BASE_PATH} && \
	git init && \
	git remote add origin git@github.com:devopsarr/${APP}-${SDK}.git || true && \
	git pull -f origin main

pre-generation: get-swagger var-generation
	python3 pre-generation-scripts/fixes.py ${APP}
	python3 pre-generation-scripts/assign_operation_id.py ${APP}
	sed -i 's/"200"/"2XX"/g' ./swaggers/${APP}.json
	rm -rf ${BASE_PATH}/${APP}
	mkdir ${BASE_PATH}/${APP}
	make ignore-${SDK}

generate: pre-generation
	docker run --rm \
    -v $$PWD:/local ${OPENAPI_GENERATOR_IMAGE} generate \
    -c /local/vars/${APP}-${SDK}.yaml \
	--openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true
	sudo chown -R runner ${BASE_PATH}/
	make post-${SDK}

post-go:
	mv ${BASE_PATH}/${APP}/README.md ${BASE_PATH}/README.md
	mv ${BASE_PATH}/${APP}/.gitignore ${BASE_PATH}/.gitignore
	mv .generated-code/${APP}-go/${APP}/go.mod .generated-code/${APP}-go/go.mod
	cd .generated-code/${APP}-go/ && go mod tidy
	rm ${BASE_PATH}/${APP}/.openapi-generator-ignore
	mkdir ${BASE_PATH}/.github || true
	mkdir ${BASE_PATH}/.github/workflows || true
	cp templates/${SDK}/golang.yml ${BASE_PATH}/.github/workflows/golang.yml
	cp templates/${SDK}/.goreleaser.yml ${BASE_PATH}/.goreleaser.yml

post-py:
	rm ${BASE_PATH}/.openapi-generator-ignore
	rm -rf ${BASE_PATH}/.openapi-generator/
	for file in ${PY_VERSION_FILES} ; do \
    	sed -i 's/\(.*${VERSION}.*\)/\1 # x-release-please-version/' ${BASE_PATH}/$$file ; \
	done
	sed -i 's/\(.*def to_debug_report.*\)/# x-release-please-start-version\'$$'\n''\1/' ${BASE_PATH}/${APP}/configuration.py
	sed -i 's/\(.*def get_host_settings.*\)/# x-release-please-end\'$$'\n''\1/' ${BASE_PATH}/${APP}/configuration.py
	sed -i 's/\(.*- API version.*\)/[comment]: # (x-release-please-start-version)\'$$'\n''\1/' ${BASE_PATH}/README.md
	sed -i 's/\(.*## Requirements.*\)/[comment]: # (x-release-please-end)\'$$'\n''\1/' ${BASE_PATH}/README.md

git-push:
	cd ${BASE_PATH} && \
	git checkout -b feature/code-generation && \
	git add . && \
	git commit -m "build: generate code" && \
	git push -f

ignore-go:
	cp templates/${SDK}/.openapi-generator-ignore ${BASE_PATH}/${APP}/.openapi-generator-ignore

ignore-py:
	cp templates/${SDK}/.openapi-generator-ignore ${BASE_PATH}/.openapi-generator-ignore
