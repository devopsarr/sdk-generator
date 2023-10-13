APP ?= prowlarr
SDK ?= py
URL ?= https://raw.githubusercontent.com/Prowlarr/Prowlarr/7e32b54547a18fcf896cc12249533894c927ccd0/src/Prowlarr.Api.V1/openapi.json
VERSION ?= 0.6.0
OPENAPI_GENERATOR_IMAGE ?= openapitools/openapi-generator-cli:v6.6.0@sha256:54381220aecf2e77bb4b6694c4e1a03e733b49453292cd1af6f48b510f1f008a

get-swagger:
	mkdir swaggers || true
	curl ${URL} | yq -P -o json > ./swaggers/${APP}.json

var-generation:
	mkdir vars || true
	sed "s/servarr/${APP}/gI; s/0.0.1/${VERSION}/gI" templates/${SDK}/vars.yaml > vars/${APP}-${SDK}.yaml

git-init:
	cd .generated-code/${APP}-${SDK} && \
	git init && \
	git remote add origin git@github.com:devopsarr/${APP}-${SDK}.git || true && \
	git pull -f origin main

pre-generation: get-swagger var-generation
	python3 pre-generation-scripts/fixes.py ${APP}
	python3 pre-generation-scripts/assign_operation_id.py ${APP}
	rm -rf .generated-code/${APP}-${SDK}/${APP}
	mkdir .generated-code/${APP}-${SDK}/${APP}
	make ignore-${SDK}

generate: pre-generation
	docker run --rm \
    -v $$PWD:/local ${OPENAPI_GENERATOR_IMAGE} generate \
    -c /local/vars/${APP}-${SDK}.yaml
	make post-${SDK}

post-go:
	mv .generated-code/${APP}-${SDK}/${APP}/README.md .generated-code/${APP}-${SDK}/README.md
	mv .generated-code/${APP}-${SDK}/${APP}/.gitignore .generated-code/${APP}-${SDK}/.gitignore
	mv .generated-code/${APP}-go/${APP}/go.mod .generated-code/${APP}-go/go.mod
	sudo chown -R runner .generated-code/${APP}-${SDK}/
	cd .generated-code/${APP}-go/ && go mod tidy
	rm .generated-code/${APP}-${SDK}/${APP}/.openapi-generator-ignore
	mkdir .generated-code/${APP}-${SDK}/.github || true
	mkdir .generated-code/${APP}-${SDK}/.github/workflows || true
	cp templates/${SDK}/golang.yml .generated-code/${APP}-${SDK}/.github/workflows/golang.yml
	cp templates/${SDK}/.goreleaser.yml .generated-code/${APP}-${SDK}/.goreleaser.yml

post-py:
	mv .generated-code/${APP}-py/setup.cfg .generated-code/${APP}-py/pyproject.toml
	rm .generated-code/${APP}-${SDK}/.openapi-generator-ignore

git-push:
	cd .generated-code/${APP}-${SDK} && \
	git checkout -b feature/code-generation && \
	git add . && \
	git commit -m "build: generate code" && \
	git push -f

ignore-go:
	cp templates/${SDK}/.openapi-generator-ignore .generated-code/${APP}-${SDK}/${APP}/.openapi-generator-ignore

ignore-py:
	cp templates/${SDK}/.openapi-generator-ignore .generated-code/${APP}-${SDK}/.openapi-generator-ignore
