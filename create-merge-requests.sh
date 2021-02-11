#!/usr/bin/env bash

# Documentation
# https://docs.gitlab.com/ce/api/projects.html#list-projects
# https://docs.gitlab.com/ee/api/merge_requests.html#create-mr
#
# Based on:
# https://gist.github.com/JonasGroeger/1b5155e461036b557d0fb4b3307e1e75

BASE_PATH="https://gitlab.jetshop.se/"
RAW_NAMESPACE=""
BRANCH_NAME=""


if [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
    echo "Please set the environment variable GITLAB_PRIVATE_TOKEN"
    echo "See ${BASE_PATH}profile/personal_access_tokens"
    exit 1
fi

PROJECT_PROJECTION="{ "path": .path, "git": .http_url_to_repo }"
NAMESPACE=$(printf %s $RAW_NAMESPACE | jq -sRr @uri)
FILENAME="repos.json"
trap "{ rm -f $FILENAME; }" EXIT

[ -e $FILENAME  ] && rm $FILENAME

PAGE_COUNTER=1
while true; do
    echo "Reading page $PAGE_COUNTER"

    CURL_OUT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "${BASE_PATH}api/v4/groups/$NAMESPACE/projects?per_page=999&page=$PAGE_COUNTER")
    if [ "$CURL_OUT" == "[]" ]; then break; fi


    echo $CURL_OUT | jq --raw-output --compact-output ".[] | $PROJECT_PROJECTION" >> "$FILENAME"
    let PAGE_COUNTER++
done

while read repo; do
    THEPATH=$(echo "$repo" | jq -r ".path")
    GIT=$(echo "$repo" | jq -r ".git")

    # CREATE MERGE REQUEST
    echo "$THEPATH: Creating MR for $BRANCH_NAME into master"
    CURL_OUT=$(curl -s -X POST -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" -d "{\"source_branch\": \"$BRANCH_NAME\", \"target_branch\": \"master\", \"title\": \"$BRANCH_NAME\"}" "${BASE_PATH}api/v4/projects/$NAMESPACE/merge_requests")

done < "$FILENAME"
