#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)

source <(wget -qO- https://raw.githubusercontent.com/sswastik02/bash-tui-toolkit/main/src/prompts.sh)

setup_tools() {
  echo "###############################################"
  echo "             SETTING UP TOOLS"
  echo "###############################################"
  sudo apt update -y
  sudo apt install -y build-essential git curl bat jq xclip htop
  sudo bash -c "$(curl -fsSL https://get.docker.com)"
  sudo groupadd docker
  sudo usermod -aG docker $USER
  newgrp docker <<END
    docker run hello-world
END
  sudo systemctl enable docker.service
  sudo systemctl enable containerd.service
}

setup_zsh() {
  echo "###############################################"
  echo "            SETTING UP ZSH INTERFACE"
  echo "###############################################"
  sudo apt install -y zsh
  echo -e "$bold Installing Oh-My-Zsh $normal\n"
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

  echo -e "$bold Installing Oh-My-Zsh plugins $normal\n"
  mkdir -p ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

  sed -i 's/plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g' ~/.zshrc
  echo -e "Installing powerlevel10k theme"
  sed -i 's/^ZSH_THEME=\".*\"/ZSH_THEME=\"powerlevel10k\/powerlevel10k\"/g' ~/.zshrc
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

  echo -e "$bold Downloading MesloGS Fonts into ~/.fonts $normal\n"
  mkdir -p ~/.fonts
  wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf -P ~/.fonts
  wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf -P ~/.fonts
  wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf -P ~/.fonts
  wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf -P ~/.fonts

  echo -e "$bold Setting up personal .p10k.zsh$normal"
  wget -q https://raw.githubusercontent.com/sswastik02/homesweethome/main/.p10k.zsh ~/.p10k.zsh

  echo -e "$bold Adding Aliases $normal\n"
  echo "alias clear=\"clear -x\"" >> ~/.zshrc
  echo "alias wipe=\"tput clear\"" >> ~/.zshrc
  echo "source ~/.p10k.zsh" >> ~/.zshrc # File downloaded at a later stage
  echo "export PATH=\"$HOME/.local/bin:$PATH\"" >> ~/.zshrc

  echo -e "$bold Changing Default Shell to ZSH $normal\n"
  chsh -s $(which zsh)
}

setup_guake() {
  echo "###############################################"
  echo "            SETTING UP GUAKE TERMINAL"
  echo "###############################################"
  echo -e "$bold Setting up personal guake preferences$normal"
  sudo apt install -y guake
  wget -q https://raw.githubusercontent.com/sswastik02/homesweethome/main/myguakeprefs -O /tmp/myguakeprefs
  guake --restore-preferences /tmp/myguakeprefs
}

setup_tmux() {
  echo "###############################################"
  echo "            SETTING UP TMUX CONFIG"
  echo "###############################################"
  sudo apt install -y tmux 
  echo -e "$bold Installing tmux plugins manager$normal\n"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

  echo -e "$bold Installing custom .tmux.conf$normal\n"
  wget -q https://raw.githubusercontent.com/sswastik02/homesweethome/main/.tmux.conf -O ~/.tmux.conf

  tmux source ~/.tmux.conf

  echo -e "$bold Setting Locale to en_US.UTF-8$normal"
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8
}

setup_git() {
  echo "###############################################"
  echo "            SETTING UP GIT CONFIG"
  echo "###############################################"
  # Reference
  # https://gist.github.com/petersellars/c6fff3657d53d053a15e57862fc6f567

  echo -e "$bold Setting up Github SSH$normal \n"
  ssh-keygen -q -b 4096 -t rsa -N "" -f ~/.ssh/github_rsa
  PUBKEY=`cat ~/.ssh/github_rsa.pub`
  TITLE=`hostname`

  RESPONSE=`curl -s -H "Authorization: token ${GH_TOKEN}" \
    -X POST --data-binary "{\"title\":\"${TITLE}\",\"key\":\"${PUBKEY}\"}" \
    https://api.github.com/user/keys`

  KEYID=`echo $RESPONSE \
    | grep -o '\"id.*' \
    | grep -o "[0-9]*" \
    | grep -m 1 "[0-9]*"`

  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/github_rsa

  ssh -T git@github.com

  echo -e "$bold Setting up GPG Key for signed commits$normal\n"
  # Reference
  # https://gist.github.com/woods/8970150

  noreply_email=$(curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/user \
    | jq -r '"\(.id)+\(.login)@users.noreply.github.com"')

  git_login=$(curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/user \
    | jq -r '.login')

  read -p "Enter name for GPG Key ($git_login): " GPG_USERNAME
  read -p "Enter email for GPG Key ($noreply_email): " GPG_MAIL
  read -sp "Enter passphrase for GPG Key: " GPG_PASSPHRASE 
  echo -e "\n"

  GPG_MAIL=${GPG_MAIL:-$noreply_email}
  GPG_USERNAME=${GPG_USERNAME:-$git_login}

  cat >/tmp/gpg_config <<EOF
       %echo Generating a basic OpenPGP key...
       Key-Type: RSA
       Key-Length: 4096 
       Subkey-Type: RSA 
       Subkey-Length: 4096 
       Name-Real: $GPG_USERNAME
       Name-Email: $GPG_MAIL 
       Expire-Date: 0
       Passphrase: $GPG_PASSPHRASE 
       # Do a commit here, so that we can later print "done" :-)
       %commit
       %echo done
EOF

  gpg --batch --full-generate-key /tmp/gpg_config
  gpg_key_id=$(gpg --list-keys "$GPG_USERNAME" | awk '/^pub/{getline; print $1; exit}')

  gpg_key=$(gpg --armor --export $gpg_key_id | awk 'BEGIN{ORS="\\n"}{$1=$1}1')

  RESPONSE=$(curl -s -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "{\"name\": \"${TITLE}\",\"armored_public_key\":\"$gpg_key\"}" \
    https://api.github.com/user/gpg_keys)

  git config --global --unset gpg.format
  git config --global user.signingkey $gpg_key_id 
  git config --global commit.gpgsign true

  git config --global user.email $noreply_email
  git config --global user.name $git_login
}

setup_nvim() {

  echo "###############################################"
  echo "            SETTING UP NVIM CONFIG"
  echo "###############################################"
  sudo apt install -y vim vim-gtk
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
  sudo rm -rf /opt/nvim
  sudo tar -C /opt -xzf nvim-linux64.tar.gz

  echo 'export PATH="$PATH:/opt/nvim-linux64/bin"' >> ~/.zshrc
  export PATH="$PATH:/opt/nvim-linux64/bin"

  git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1 && nvim

}

disable_sudo_if_not_present() {
  if ! command -v sudo >/dev/null 2>&1; then
    alias sudo='';
  fi
}

usage() {

  echo "Usage: $0 [OPTIONS]"
  echo "If no options specified, script executes in interactive mode"
  echo "Options:"
  echo "-t, --tools     setup tools"
  echo "-z, --zsh       setup zsh"
  echo "-e, --guake     setup guake"
  echo "-x, --tmux      setup tmux"
  echo "-n, --nvim      setup nvim"
  echo "-g, --git <PAT> setup git"
  echo "-h, --help      see help"

}

choices=("tools" "zsh" "guake" "tmux" "nvim" "git" "help")

if [[ $# -eq 0 ]]; then
  option_idx=$(checkbox "Select steps to be followed" ${choices[@]})
  options_selected=()
  for i in $option_idx; do
    options_selected+=(--${choices[$i]})
  done
else
  options_selected=$@
fi

OPTIONS=$(getopt -o genzxth --long tools,zsh,guake,tmux,nvim,git:,help -n 'parse-options' -- "$options_selected")

if [ $? != 0 ]; then
    echo "Failed to parse options." >&2
    usage
    exit 1
fi
atleastOneValidFlag=""

eval set -- "$OPTIONS"
disable_sudo_if_not_present
while true; do
  case "$1" in
    -t | --tools)
      setup_tools
      atleastOneValidFlag="true"
      shift
      ;;
    -z | --zsh)
      setup_zsh
      atleastOneValidFlag="true"
      shift
      ;;
    -e | --guake)
      setup_guake
      atleastOneValidFlag="true"
      shift
      ;;
    -x | --tmux)
      setup_tmux
      atleastOneValidFlag="true"
      shift
      ;;
    -n | --nvim)
      setup_nvim
      atleastOneValidFlag="true"
      shift
      ;;
    -g | --git)
      GH_TOKEN="$2"
      setup_git
      atleastOneValidFlag="true"
      shift 2
      ;;
    -h | --help)
      usage
      atleastOneValidFlag="true"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Invalid Option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z $atleastOneValidFlag ]; then
  usage
fi

