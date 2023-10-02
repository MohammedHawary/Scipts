#!/bin/bash

red() {
    echo -e "\e[91m[!]\e[0m"
}

green() {
    echo -e "\e[92m[+]\e[0m"
}

check_if_run_as_root(){
    if [ "$EUID" -ne 0 ]; then
    echo "$(red "[!]") This script must be run as root."
    exit 1
    fi
}

check_if_go_installed(){
    if ! command -v go &> /dev/null; then
    echo "$(red "[!]") Go is not installed. Installing..."
    wget https://golang.org/dl/go1.17.linux-amd64.tar.gz 2> /dev/null 
    tar -C /usr/local -xzf go1.17.linux-amd64.tar.gz 2> /dev/null
    export PATH=$PATH:/usr/local/go/bin
    rm go1.17.linux-amd64.tar.gz
    echo "$(green) Go installed successfully"
    fi
}

add_go_path(){
    GOPATH="$HOME/go" 
    if [[ ":$PATH:" != *":$GOPATH/bin:"* ]]; then
        export PATH="$GOPATH/bin:$PATH"
    fi
}

check_if_tools_installed(){
    add_go_path

    declare -A tools
    tools["subfinder"]="go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    tools["haktrails"]="go install -v github.com/hakluke/haktrails@latest"
    tools["assetfinder"]="https://github.com/tomnomnom/assetfinder/releases/download/v0.1.1/assetfinder-linux-386-0.1.1.tgz"
    tools["httpx"]="go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"

    for key in "${!tools[@]}"; do
        value="${tools[$key]}"
        # echo "$key => $value"
        if command -v "$key" &> /dev/null; then
            printf ""
        else
            if [[ $value == http* ]]; then
                # assetfinder
                echo "$(red) assetfinder is not installed. Installing..."
                wget $value 2> /dev/null
                tar -xzvf assetfinder-linux-386-0.1.1.tgz > /dev/null
                mv assetfinder /usr/bin/
                rm assetfinder-linux-386-0.1.1.tgz
                echo "$(green) assetfinder installed successfully."
            fi
            if [[ $value != http* ]]; then
                # subfinder,haktrails
                echo "$(red) $key is not installed. Installing..."
                $value 2> /dev/null
                echo "$(green) $key installed successfully."
            fi
        fi
    done
}

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h      Display this help message"
    echo "  -d      list of domains"
}


httpx_step(){
    echo "$(red) last step"
    chmod 777 live_domains.sh
    ./live_domains.sh
    rm live_domains.sh
    chmod 777 "Live_subdomains" -R
    chmod 777 "tools_output" -R
}

enumeration(){
    echo "$(green) starting subdomain enumeration..."

    directory_name="Live_subdomains"
    if [ ! -d "$directory_name" ]; then
        while read domain;do
            mkdir -p "Live_subdomains/$domain" 
        done < $1
    fi
    directory_name="tools_output"
    if [ ! -d "$directory_name" ]; then
        while read domain;do
            mkdir -p "tools_output/$domain"
        done < $1
    fi


    while read -r Rdomain; do
        domain="${Rdomain// /}"
        echo "$(green) $domain subdomain enumeration... "
        subfinder -d $domain -o tools_output/$domain/subf.txt 2> /dev/null > /dev/null
        echo $domain | haktrails subdomains > tools_output/$domain/haksubs.txt 2> /dev/null
        assetfinder -subs-only $domain > tools_output/$domain/asset.txt 2> /dev/null
        cat tools_output/$domain/subf.txt tools_output/$domain/haksubs.txt tools_output/$domain/asset.txt | sort -u > tools_output/$domain/subdomains.txt 2> /dev/null
        echo "httpx -l tools_output/$domain/subdomains.txt -o \"Live_subdomains/$domain/activesubs_WithStatusCode.txt\" -threads 200 -status-code -follow-redirects 2> /dev/null > /dev/null" >> live_domains.sh
        echo "while read line; do cleaned_string=\$(echo \"\$line\" | sed -E 's/(https?:\/\/[^ ]+).*/\1/'); echo \"\$cleaned_string\" >> \"Live_subdomains/$domain/activesubs_WithoutStatusCode.txt\"; done< \"Live_subdomains/$domain/activesubs_WithStatusCode.txt\"">> live_domains.sh
        echo "$(green) $domain \e[91m=>\e[0m subdomins enumeration done"
    done < $1
    httpx_step
}


check_if_run_as_root
check_if_go_installed
check_if_tools_installed

while getopts "hd:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        d)
            enumeration $OPTARG
            ;;
        \?)
            echo $(red "Invalid option: -$OPTARG") >&2
            show_help
            exit 1
            ;;
    esac
done

# Check if no options were provided
if [ $OPTIND -eq 1 ]; then
    show_help
    exit 0
fi