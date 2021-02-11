#!/usr/bin/env bash

# Documentation
# https://docs.gitlab.com/ce/api/projects.html#list-projects
#
# Based on:
# https://gist.github.com/JonasGroeger/1b5155e461036b557d0fb4b3307e1e75

BASE_PATH="https://gitlab.example.com"
RAW_NAMESPACE=""
DELETE_OLDER_THAN="2month"

if [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
    echo "Please set the environment variable GITLAB_PRIVATE_TOKEN"
    echo "See ${BASE_PATH}profile/personal_access_tokens"
    exit 1
fi

IMAGE_REPO_PROJECTION="{ "id": .id, "project_id": .project_id, "path": .path }"
NAMESPACE=$(printf %s $RAW_NAMESPACE | jq -sRr @uri)
FILENAME="repos_except_master.json"
FILENAME2="repos_master.json"
trap "{ rm -f $FILENAME; }" EXIT
trap "{ rm -f $FILENAME2; }" EXIT

[ -e $FILENAME  ] && rm $FILENAME
[ -e $FILENAME  ] && rm $FILENAME2

PAGE_COUNTER=1
while true; do
    echo "Reading page $PAGE_COUNTER"

    CURL_OUT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "${BASE_PATH}api/v4/groups/$NAMESPACE/registry/repositories?per_page=999&page=$PAGE_COUNTER")
    if [ "$CURL_OUT" == "[]" ]; then break; fi

    echo $CURL_OUT | jq --raw-output --compact-output ".[] | select( .name != \"master\" ) | $IMAGE_REPO_PROJECTION" >> "$FILENAME"
    echo $CURL_OUT | jq --raw-output --compact-output ".[] | select( .name == \"master\" ) | $IMAGE_REPO_PROJECTION" >> "$FILENAME2"
    let PAGE_COUNTER++
done

while read repo; do
    ID=$(echo "$repo" | jq -r ".id")
    PROJECT_ID=$(echo "$repo" | jq -r ".project_id")
    THEPATH=$(echo "$repo" | jq -r ".path")

    # DELETE ALL IMAGE TAGS FOR THE REPOS THAT ARE NOT MASTER
    echo "Deleting all non-master image tags for $THEPATH ( id: $PROJECT_ID )"
    CURL_OUT=$(curl -s -X DELETE -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "${BASE_PATH}api/v4/projects/$PROJECT_ID/registry/repositories/$ID/tags?name_regex_delete=.*")

    # DELETE THE REGISTRY REPOS THAT ARE NOT MASTER
    echo "Deleting all non-master registry repos for $THEPATH ( id: $PROJECT_ID )"
    CURL_OUT2=$(curl -s -X DELETE -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "${BASE_PATH}api/v4/projects/$PROJECT_ID/registry/repositories/$ID")

done < "$FILENAME"

while read repo; do
    ID=$(echo "$repo" | jq -r ".id")
    PROJECT_ID=$(echo "$repo" | jq -r ".project_id")
    THEPATH=$(echo "$repo" | jq -r ".path")

    # DELETE ALL IMAGE TAGS IN MASTER THAT ARE OLDER THAN $DELETE_OLDER_THAN
    echo "Deleting all master images for $THEPATH older than $DELETE_OLDER_THAN ( id: $PROJECT_ID )"
    CURL_OUT=$(curl -s -X DELETE -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "${BASE_PATH}api/v4/projects/$PROJECT_ID/registry/repositories/$ID/tags?name_regex_delete=.*&older_than=$DELETE_OLDER_THAN&keep_n=10")

done < "$FILENAME2"
