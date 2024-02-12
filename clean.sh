#!/bin/bash

GH_TOKEN=$1 # Github PAT is required with access `admin:public:key`

read -p "Enter GPG_USERNAME ($USER):" GPG_USERNAME
GPG_USERNAME=${GPG_USERNAME:-$USER}
echo -e "GPG_USERNAME=$GPG_USERNAME"
TITLE=$(hostname)

sudo rm -rf \
	~/.zshrc \
	~/.oh-my-zsh \
	~/.ssh/github_rsa* \
	~/.fonts/Meslo* 

KEY_ID=$(curl -sL \
	-H "Accept: application/vnd.github+json" \
      	-H "Authorization: Bearer $GH_TOKEN" \
      	-H "X-GitHub-Api-Version: 2022-11-28"   https://api.github.com/user/keys \
	| jq ". [] | select (.title == \"$TITLE\") | .id")

echo -e "KEY_ID=$KEY_ID"

curl \
	-X DELETE \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: token $GH_TOKEN" \
	https://api.github.com/user/keys/$KEY_ID

gpg --list-keys "$GPG_USERNAME" | awk '/^pub/{getline; print $1; exit}' | xargs gpg --delete-keys
gpg --list-keys "$GPG_USERNAME" | awk '/^pub/{getline; print $1; exit}' | xargs gpg --delete-secret-keys

GPG_ID=$(curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/users/sswastik02/gpg_keys \
  | jq ". [] | select( .name == \"$TITLE\") | .id")

RESPONSE=$(curl -L \
  -X DELETE \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN"  \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/user/gpg_keys/$GPG_ID")
sudo timeshift --restore
