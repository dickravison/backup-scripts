#!/bin/bash
source ./git.env

#Get repos in GitHub
repos=$(gh repo list $GITHUB_USER --json name -q '.[].name')
#Loop over each repository and checks if it exists in Gitea.
#If it doesn't exist, then create a repository and mirror it from GitHub.
for repo in $repos; do
	EXISTS=$(curl -s -H "Accept: application/json" -H "Authorization: token $GITEA_TOKEN" $GITEA_ADDR/api/v1/repos/$GITEA_USER/$repo | grep "The target couldn't be found" | wc -l)
	if [ $EXISTS -gt 0 ]; then
		echo "${repo} doesn't exist in Gitea, creating mirror"
		RESPONSE=$(curl -s -XPOST -H "Content-Type: application/json" -H "Authorization: token $GITEA_TOKEN" $GITEA_ADDR/api/v1/repos/migrate -d '{"clone_addr":"https://github.com/'$GITHUB_USER'/'$repo'","auth_token":"'$GITHUB_TOKEN'","mirror":true,"private":true,"repo_name":"'$repo'"}')
		echo $RESPONSE
	else
		echo "${repo} already exists in Gitea"
	fi
done

