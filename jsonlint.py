import sys
import json
import argparse

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('filename', type=str, help='Path to json file')
    args = parser.parse_args()

    filename = args.filename
    try:
        fhandle = open(filename, 'rb')
    except OSError as error:
        print(error)
        sys.exit(1)
    else:
        fcontents = fhandle.read()

try:
    data = json.loads(fcontents)
except ValueError as error:
    print(error)
    sys.exit(1)
else:
    sys.exit(0)
