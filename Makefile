APP ?= sonarr
SDK ?= py
URL ?= https://raw.githubusercontent.com/Sonarr/Sonarr/3d24e412a692b5b4414f81cad2ae8167daaed27d/src/Sonarr.Api.V3/openapi.json
VERSION ?= 0.6.0

get-swagger:
	mkdir swaggers || true
	curl -o ./swaggers/${APP}.json ${URL}

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
    -v $$PWD:/local openapitools/openapi-generator-cli generate \
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
