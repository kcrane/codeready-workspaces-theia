#!/bin/bash
#set -x

FILENAMES=""
OVERWRITE_FILES="false"
GITHUB_RELEASE_DESC=""
GITHUB_RELEASE_COMMITISH="master"
GITHUB_REPO=""
GITHUB_TAG=""
while (( "$#" )) ; do
    case "$1" in
        -r|--repo)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ] ; then
                GITHUB_REPO="$2"
                shift 2
            else
                echo "ERROR: repo name missing for $1"
                exit 1
            fi
            ;;
        -t|--tag)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ] ; then
                GITHUB_TAG="$2"
                shift 2
            else
                echo "ERROR: tag missing for $1"
                exit 1
            fi
            ;;
        -n|--newrelease)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ] ; then
                GITHUB_RELEASE_DESC="$2"
		if [ -n "$3" ] && [ ${3:0:1} != "-" ] ; then
	            GITHUB_RELEASE_COMMITISH="$3"
		    shift
		fi
                shift 2
            fi
            ;;
        -o|--overwrite)
            OVERWRITE_FILES="true"
            shift
            ;;
        -h|--help)
            echo "github-upload.sh -r git-user/repo -t git-tag [-n [desc [commitish]]] [-o] filename [filename|...]"
	    echo "    -r   github user/repo"
	    echo "    -t   release tag"
	    echo "    -n   optional.  create new release if tag does not exist.  optional description and commitish (sha or branch) to base release on"
	    echo "    -o   overwrite assets if already exist in release"
	    echo ""
	    echo "Example: github-upload.sh -r redhat-developer/codeready-workspaces-deprecated -t 2.2.0.GA -n '2.2.0.GA release' master -o *.tar.gz"
            exit 0
            ;;
        *)
            FILENAMES="$1 $FILENAMES"
            shift
            ;;
    esac
done

function check_resp {
    GITHUB_RESP="$(echo $1 | sed -E 's|(.*) *([0-9]{3})$|\1|g')"
    HTTP_CODE="$(echo $1 | sed -E 's|(.*) *([0-9]{3})$|\2|g')"
    if [ -z "GITHUB_RESP" ] || [ -z "HTTP_CODE" ] || [ "$HTTP_CODE" -lt 200 ] ||  [ "$HTTP_CODE" -gt 300 ]  ; then
        echo -e "ERROR: Failed calling github api with http code $HTTP_CODE: $GITHUB_RESP"
        exit 1;
    fi
}

# Check parameters are valid
GITHUB_AUTH="Authorization: token $GITHUB_TOKEN"
GITHUB_RESP="$(curl -sH "$GITHUB_AUTH" -w "%{http_code}" "https://api.github.com/repos/${GITHUB_REPO}" 2> /dev/null)" || { echo "ERROR: Unable to reach github"; exit 1; }
check_resp "$GITHUB_RESP"
for f in $FILENAMES ; do
    [ -e "$f" ] || { echo "ERROR: file does not exist $f"; exit 1; }
done

# Get/Create release id
JSON_BODY="$(cat << MYEOF
{
  "tag_name": "$GITHUB_TAG",
  "target_commitish": "$GITHUB_RELEASE_COMMITISH",
  "name": "$GITHUB_TAG",
  "body": "$GITHUB_RELEASE_DESC",
  "draft": false,
  "prerelease": false
}
MYEOF
)"
GITHUB_RESP="$(curl -sH "$GITHUB_AUTH" -w "%{http_code}" "https://api.github.com/repos/${GITHUB_REPO}/releases" 2> /dev/null)" 
check_resp "$GITHUB_RESP"
RELEASE_RESP="$(echo $GITHUB_RESP | jq -r '.[] | select(.tag_name=="'$GITHUB_TAG'")')"
RELEASE_ID=$(echo "$RELEASE_RESP" | jq -r '.id')
if [ -z "$RELEASE_ID" ] ; then
    if [ -z "$GITHUB_RELEASE_DESC" ] ; then
        echo "ERROR: Tag $GITHUB_TAG doesn't exist.  Try running with -d or pre-create tag"
	exit 1
    fi
    echo "Creating Release $GITHUB_TAG..."
    GITHUB_RESP="$(curl -sH "$GITHUB_AUTH"  -H "Content-Type: application/json" -d "$JSON_BODY" -w "%{http_code}" "https://api.github.com/repos/${GITHUB_REPO}/releases")"
    check_resp "$GITHUB_RESP"
    RELEASE_RESP="$GITHUB_RESP"
    RELEASE_ID="$(echo "$RELEASE_RESP" | jq -r '.id')"
else
    echo "$GITHUB_TAG Found!"
fi

# Upload asset
for f in $FILENAMES ; do
    ASSET_ID="$(echo $RELEASE_RESP | jq -r '.assets[] | select(.name=="'$(basename "$f")'") | .id')" 
    if [ ! -z "$ASSET_ID" ] ; then
        if [ "$OVERWRITE_FILES" == "true" ] ; then
            echo "Deleting $(basename "$f")..."
	    GITHUB_RESP="$(curl -X "DELETE" -sH "$GITHUB_AUTH" -w "%{http_code}" "https://api.github.com/repos/${GITHUB_REPO}/releases/assets/$ASSET_ID")"
	    check_resp "$GITHUB_RESP"
	else
            echo "Asset $(basename $f) exists.  Try running with -o to overwrite it"
	    exit 1
	fi
    fi
    echo "Uploading $(basename "$f")..."
    GITHUB_RESP="$(curl --data-binary @"$f" -sH "$GITHUB_AUTH" -H "Content-Type: application/octet-stream" -w "%{http_code}" "https://uploads.github.com/repos/${GITHUB_REPO}/releases/${RELEASE_ID}/assets?name=$(basename $f)")"
    check_resp "$GITHUB_RESP"
done
