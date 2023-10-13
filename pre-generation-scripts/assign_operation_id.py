
# Script to add operationId

import json
import re
import sys

app = sys.argv[1]

# Opening JSON file
with open(f'./swaggers/{app}.json', 'r') as f:
    # returns JSON object as a dictionary
    data = json.load(f)

# Loop over paths
for path, methods in data['paths'].items():
    # for each method adjust the name
    for method, details in methods.items():
        method_name = re.split('/|-', re.sub("^\/api\/v\d\/(.*)$","\\1", path))
        if method_name[-1].startswith("{"):
            method_name[-1] = method_name[-1].strip('{}')
            method_name.insert(-1,"by")
        final_method= method
        if method == "delete" and len(method_name) > 1 and method_name[-2] == "by":
            method_name = method_name[:-2]
        if method == "put" and len(method_name) > 1 and method_name[-2] == "by":
            final_method = "update"
            method_name = method_name[:-2]
        if method == "post":
            final_method = "create"
            if method_name[-1].startswith("test"):
                final_method = method_name[-1]
                method_name = method_name[:-1]
        if (method == "get" and
            details['responses'].get('200', {}).get('content', {}).get('application/json', {}).get('schema', {}).get('type') == "array"):
            final_method = "list"

        # Manage configs
        if len(method_name) > 1 and method_name[0] == "config":
            method_name[0] = method_name[1]+method_name[0]
            method_name.remove(method_name[1])

        # Manage settings
        if len(method_name) > 1 and method_name[1] == "settings":
            method_name.remove(method_name[1])

        for index, name in enumerate(method_name):
            # Use camelcase for resources
            if name.casefold() == details['tags'][0].casefold():
                method_name[index] = details['tags'][0]

            # Remove middle elements
            if name.startswith("{"):
                method_name.remove(name)

        method_name.insert(0,final_method)
        data['paths'][path][method]['operationId'] = ''.join([i[0].upper() + i[1:] for i in method_name if len(i) > 0])

# Overwrite file content
with open(f'./swaggers/{app}.json', 'w') as f:
    f.write(json.dumps(data, indent=2))