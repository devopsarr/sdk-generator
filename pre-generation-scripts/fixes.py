
# Script to add operationId

import json
import re
import sys

app = sys.argv[1]
api_version = sys.argv[2]

# Opening JSON file
with open(f'./swaggers/{app}.json', 'r') as f:
    # returns JSON object as a dictionary
    data = json.load(f)

data ['info']['version'] = api_version

if app != "overseerr":
    # get timespan as string
    data['components']['schemas']['TimeSpan'] = {
        "type": "string",
    }

    # get httpuri as string
    data['components']['schemas']['HttpUri'] = {
        "type": "string"
    }

    # get version as string
    data['components']['schemas']['Version'] = {
        "type": "string"
    }

    # remove broken path
    del data['paths']['/']

if app == "sonarr":
    # add SeriesLookup return type
    data['paths']['/api/v3/series/lookup']['get']['responses']['200']['content'] = {
        "application/json": {
            "schema": {
                "type": "array",
                "items": {
                "$ref": "#/components/schemas/SeriesResource"
                }
            }
        }
    }

    # fix release profile required and ignored
    data['components']['schemas']['ReleaseProfileResource']['properties']['required'] = {
        "type": "array",
        "items": {
            "type": "string"
        },
        "nullable": True
    }
    data['components']['schemas']['ReleaseProfileResource']['properties']['ignored'] = {
        "type": "array",
        "items": {
            "type": "string"
        },
        "nullable": True
    }

if app == "radarr":
    movie_resource = {
        "application/json": {
            "schema": {
                "type": "array",
                "items": {
                "$ref": "#/components/schemas/MovieResource"
                }
            }
        }
    }
    # add MoviesLookup return type
    data['paths']['/api/v3/movie/lookup']['get']['responses']['200']['content'] = movie_resource
    data['paths']['/api/v3/movie/lookup/tmdb']['get']['responses']['200']['content'] = movie_resource
    data['paths']['/api/v3/movie/lookup/imdb']['get']['responses']['200']['content'] = movie_resource

if app == 'radarr' or app == 'sonarr':
    # add custom format schema return type
    data['paths']['/api/v3/customformat/schema']['get']['responses']['200']['content'] = {
        "application/json": {
            "schema": {
                "type": "array",
                "items": {
                "$ref": "#/components/schemas/CustomFormatSpecificationSchema"
                }
            }
        }
    }

    # add auto tagging schema return type
    data['paths']['/api/v3/autotagging/schema']['get']['responses']['200']['content'] = {
        "application/json": {
            "schema": {
                "type": "array",
                "items": {
                "$ref": "#/components/schemas/AutoTaggingSpecificationSchema"
                }
            }
        }
    }

if app == 'lidarr':
    # add custom format schema return type
    data['paths']['/api/v1/customformat/schema']['get']['responses']['200']['content'] = {
        "application/json": {
            "schema": {
                "type": "array",
                "items": {
                "$ref": "#/components/schemas/CustomFormatSpecificationSchema"
                }
            }
        }
    }

    # add auto tagging schema return type
    data['paths']['/api/v1/autotagging/schema']['get']['responses']['200']['content'] = {
        "application/json": {
            "schema": {
                "type": "array",
                "items": {
                "$ref": "#/components/schemas/AutoTaggingSpecificationSchema"
                }
            }
        }
    }

if app == "whisparr":
    # add missing import list type
    if not "plex" in data['components']['schemas']['ImportListType']['enum']:
        data['components']['schemas']['ImportListType']['enum'].append("plex")

if app == "prowlarr":
    del data['paths']['/{id}/api']
    del data['paths']['/{id}/download']

if app == "overseerr":
    data['paths']['/user']['get']['responses']['200']['content']['application/json']['schema']['properties']['results']['items'] = {
        "$ref": "#/components/schemas/User",
    }

    data['paths']['/settings/discover/{sliderId}']['put']['parameters'] = [
            {
                "in": "path",
                "name": "sliderId",
                "required": True,
                "schema": {
                    "type": "number"
                }
            }
        ]

# Overwrite file content
with open(f'./swaggers/{app}.json', 'w') as f:
    f.write(json.dumps(data, indent=2))
