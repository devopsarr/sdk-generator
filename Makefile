APP ?= prowlarr
SDK ?= go
VERSION ?= 0.6.0
BASE_SWAGGER_URL ?= https://raw.githubusercontent.com/
API_VERSION ?= v1.12.2.4211
REPO ?= Prowlarr/Prowlarr
API_PATH ?= /src/Prowlarr.Api.V1/openapi.json
URL ?= ${BASE_SWAGGER_URL}${REPO}/${API_VERSION}${API_PATH}
OPENAPI_GENERATOR_IMAGE ?= openapitools/openapi-generator-cli:v7.15.0@sha256:509f01c3c7eee9d1ad286506a7b6aa4624a95b410be9a238a306d209e900621f
BASE_PATH ?= .generated-code/${APP}-${SDK}
PY_VERSION_FILES ?= setup.py pyproject.toml ${APP}/__init__.py ${APP}/api_client.py ${APP}/configuration.py

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
	python3 pre-generation-scripts/fixes.py ${APP} ${API_VERSION}
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
	sed -i 's/\(Package version.*${VERSION}.*\)/\1 <!--- x-release-please-version -->/' ${BASE_PATH}/README.md

post-go:
	rm -rf ${BASE_PATH}/docs
	cp -r ${BASE_PATH}/${APP}/docs ${BASE_PATH}/
	rm -rf ${BASE_PATH}/${APP}/docs
	mv ${BASE_PATH}/${APP}/README.md ${BASE_PATH}/README.md
	mv ${BASE_PATH}/${APP}/.gitignore ${BASE_PATH}/.gitignore
	mv ${BASE_PATH}/${APP}/go.mod ${BASE_PATH}/go.mod
	cd ${BASE_PATH} && go mod tidy
	rm ${BASE_PATH}/${APP}/.openapi-generator-ignore
	rm -rf ${BASE_PATH}/${APP}/.openapi-generator/
	rm -rf ${BASE_PATH}/${APP}/api/
	sed -i 's/\(.*${VERSION}.*\)/\1 \/\/ x-release-please-version/' ${BASE_PATH}/${APP}/configuration.go
	for file in $$(find ${BASE_PATH} -name "*.md") ; do \
    	sed -i 's/"github.com\/devopsarr\/${APP}-go"/"github.com\/devopsarr\/${APP}-go\/${APP}"/g' $$file ; \
	done
	### TO NOT DOWNGRADE ###
	sed -i 's/go 1.18/go 1.19/g' ${BASE_PATH}/go.mod

post-py:
	rm ${BASE_PATH}/.openapi-generator-ignore
	rm -rf ${BASE_PATH}/.openapi-generator/
	sed -i 's/\(SDK Package Version: \)${VERSION}/\1 \{v\}/' ${BASE_PATH}/${APP}/configuration.py
	sed -i 's/\(env=sys.platform, pyversion=sys.version\)/\1, v="${VERSION}"/' ${BASE_PATH}/${APP}/configuration.py
	for file in ${PY_VERSION_FILES} ; do \
    	sed -i 's/\(.*${VERSION}.*\)/\1 # x-release-please-version/' ${BASE_PATH}/$$file ; \
	done

post-rs:
	rm ${BASE_PATH}/.openapi-generator-ignore
	rm -rf ${BASE_PATH}/.openapi-generator/
	rm -rf ${BASE_PATH}/${APP}
	sed -i 's/\(.*${VERSION}.*\)/\1 # x-release-please-version/' ${BASE_PATH}/Cargo.toml
	sed -i 's/\(.*${VERSION}.*\)/\1 \/\/ x-release-please-version/' ${BASE_PATH}/src/apis/configuration.rs
	mkdir -p ${BASE_PATH}/.github/workflows
	cp templates/${SDK}/rust.yml ${BASE_PATH}/.github/workflows/rust.yml

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

ignore-rs:
	cp templates/${SDK}/.openapi-generator-ignore ${BASE_PATH}/.openapi-generator-ignore
