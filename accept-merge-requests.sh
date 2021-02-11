#!/usr/bin/env bash

# Documentation
# https://docs.gitlab.com/ce/api/projects.html#list-projects
#
# Based on:
# https://gist.github.com/JonasGroeger/1b5155e461036b557d0fb4b3307e1e75

BASE_PATH="https://gitlab.example.com/"
RAW_NAMESPACE=""
BRANCH_NAME=""

if [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
    echo "Please set the environment variable GITLAB_PRIVATE_TOKEN"
    echo "See ${BASE_PATH}profile/personal_access_tokens"
    exit 1
fi

MR_PROJECTION="select( .source_branch == \"$BRANCH_NAME\" ) | { "project_id": .project_id, "mr_id": .iid, "references": .references }"
NAMESPACE=$(printf %s $RAW_NAMESPACE | jq -sRr @uri)
FILENAME="repos.json"
trap "{ rm -f $FILENAME; }" EXIT

[ -e $FILENAME  ] && rm $FILENAME

PAGE_COUNTER=1
while true; do
    echo "Reading page $PAGE_COUNTER"

    CURL_OUT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "${BASE_PATH}api/v4/groups/$NAMESPACE/merge_requests?state=opened&per_page=999&page=$PAGE_COUNTER")
    if [ "$CURL_OUT" == "[]" ]; then break; fi

    echo $CURL_OUT | jq --raw-output --compact-output ".[] | $MR_PROJECTION" >> "$FILENAME"
    let PAGE_COUNTER++
done

while read repo; do
    ID=$(echo "$repo" | jq -r ".project_id")
    IID=$(echo "$repo" | jq -r ".mr_id")
    REF=$(echo "$repo" | jq -r ".reference | .full")

    # ACCEPT MERGE REQUEST
    echo "Accepting merge request for $REF"
    CURL_OUT=$(curl -s -X PUT -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "${BASE_PATH}api/v4/projects/$ID/merge_requests/$IID/merge")

done < "$FILENAME"
