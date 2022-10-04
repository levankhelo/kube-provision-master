#!/bin/bash


export NORUN="NO"
export DEBIAN_FRONTEND=noniteractive

if [[ "$(uname -s)" == "Darwin" ]]; then 
    OS="macos"        
elif [[ "$(uname -s)" == "Linux" ]]; then
    OS="linux"
else
    echo "Only Linux and Darwin/MacOS is supported"; 
    exit; 
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--test)
      TEST="$2"
      shift
      shift
      ;;
    --master)
      MASTER=YES
      shift
      ;;
    --slave)
      MASTER=NO
      shift
      ;;
    --macos)
      OS="macos"
      shift
      ;;
    --linux)
      OS="linux"
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done





function update_package_manager() {

    if [[ $OS="macos" ]]; then
        # install brew
        if [[ $(where brew | wc -l) -lt 1 ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1
        fi
    elif [[ $OS="linux" ]]; then 
        # update packages
        sudo kill -9 $(ps aux | grep unattended-upgr | awk {'print $2'}) > /dev/null 2>&1 
        sudo apt-get update > /dev/null 2>&1 
    fi

    echo "+++ package manager is updated";
}


function install_dependencies() {

    # install
    if [[ $OS="macos" ]]; then
        brew install curl wget > /dev/null 2>&1 
    elif [[ $OS="linux" ]]; then
        sudo apt-get install -y curl wget ca-certificates apt-transport-https > /dev/null 2>&1 
    fi
}

function install_kubectl() {
    if [[ $OS="macos" ]]; then
        brew install kubectl 

        if [[ $(where kubectl | wc -l) -lt 1 ]]; then
            echo "--- kubectl not installed"; exit
        fi
    elif [[ $OS="linux" ]]; then
        if [[ ! -f ~/.ssh/id_rsa || ! -f ~/.ssh/id_rsa.pub  ]]; then
            ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
        fi

        sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        sudo apt-get update && sudo apt-get install -y kubectl
        if [[ ! -x kubectl ]]; then
            echo "--- kubectl not installed"; exit
        fi
    fi
    echo "+++ kubectl installed";
}

function install_kubeadm() {
    if [[ $OS="macos" ]]; then
        brew install kubeadm
        if [[ $(where kubeadm | wc -l) -lt 1 ]]; then
            echo "--- kubeadm not installed"; exit
        fi

    elif [[ $OS="linux" ]]; then
        apt-get install -y kubeadm
        if [[ ! -x kubeadm ]]; then
            echo "--- kubeadm not installed"; exit
        fi
    fi
    echo "+++ kubeadm installed";
}

function configure_local_environment() {
   
    if [[ $OS="macos" ]]; then
        # setup for zsh
        if [[ ! -f ~/.zshrc ]]; then 
            echo >> ~/.zshrc
        if [[ $(cat ~/.zshrc | grep "source <(kubectl completion zsh)" | wc -l) -lt 1 ]]; then
            echo "source <(kubectl completion zsh)" >> ~/.zshrc
        fi

        # setup for bash
        brew install bash
        brew install bash-completion@2
        if [[ $(cat ~/.bash_profile | grep "source <(kubectl completion bash)" | wc -l) -lt 1 ]]; then
            echo 'source <(kubectl completion bash)' >>~/.bash_profile
        fi
        kubectl completion bash >/usr/local/etc/bash_completion.d/kubectl

        source <(kubectl completion bash)
        source <(kubectl completion zsh)

    elif [[ $OS="linux" ]]; then
        # setup for bash
        kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
        source <(kubectl completion bash)
    fi

}

function run(){
    # TODO: add support to M1
    update_package_manager
    install_dependencies;
    install_kubectl;
    install_kubeadm;
    configure_local_environment;
    
}

if [[ $NORUN=="NO" ]]; then
    run()
fi