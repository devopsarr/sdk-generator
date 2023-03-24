
# Script to add operationId

import json
import re
import sys

app = sys.argv[1]

# Opening JSON file
with open(f'./swaggers/{app}.json', 'r') as f:
    # returns JSON object as a dictionary
    data = json.load(f)

# get timespan as string
data['components']['schemas']['TimeSpan'] = {
    "type": "string",
    "pattern": "\d{2}:\d{2}:\d{2}"
}

# get httpuri as string
data['components']['schemas']['HttpUri'] = {
    "type": "string"
}

# get version as string
data['components']['schemas']['Version'] = {
    "type": "string"
}

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

if app == "readarr":
    # add notification flags
    flag = {"type": "boolean"}
    data['components']['schemas']['NotificationResource']['properties']['onAuthorDelete'] = flag
    data['components']['schemas']['NotificationResource']['properties']['onBookDelete'] = flag
    data['components']['schemas']['NotificationResource']['properties']['onBookFileDelete'] = flag
    data['components']['schemas']['NotificationResource']['properties']['onBookFileDeleteForUpgrade'] = flag

if app == "whisparr":
    # add missing import list type
    if not "plex" in data['components']['schemas']['ImportListType']['enum']:
        data['components']['schemas']['ImportListType']['enum'].append("plex")

# Overwrite file content
with open(f'./swaggers/{app}.json', 'w') as f:
    f.write(json.dumps(data, indent=2))