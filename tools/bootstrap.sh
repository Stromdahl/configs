#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display the menu
display_menu() {
    echo "Select an action:"
    echo "1) Update & Upgrade System"
    echo "2) Install Default Packages"
    echo "3) Setup New User"
    echo "4) Setup Sudo for User"
    echo "5) Configure SSH"
    echo "6) Setup Firewall (UFW)"
    echo "7) Install Development Tools"
    echo "8) Exit"
    read -p "Enter your choice [1-8]: " choice
    echo ""
}

# Function to update & upgrade the system
update_upgrade() {
    echo "Updating and Upgrading the System..."
    apt update && apt upgrade -y
}

# Function to install default packages
install_default_packages() {
    echo "Installing Default Packages..."
    apt install -y wget curl git vim ufw sudo
}

# Function to setup a new user
setup_user() {
    read -p "Enter new username: " username
    adduser $username
}

# Function to setup sudo for a user
setup_sudo() {
    read -p "Enter username to add to sudo group: " username
    usermod -aG sudo $username
    echo "User $username added to sudo group."
}

# Function to configure SSH
configure_ssh() {
    echo "Configuring SSH..."
    apt install -y openssh-server
    systemctl enable ssh
    systemctl start ssh
    echo "SSH has been configured and started."
}

# Function to setup UFW (Uncomplicated Firewall)
setup_firewall() {
    echo "Setting up UFW..."
    ufw allow OpenSSH
    ufw enable
    echo "UFW has been enabled and SSH is allowed."
}

# Function to install development tools
install_dev_tools() {
    echo "Installing Development Tools..."
    apt install -y build-essential
}

# Main script loop
while true; do
    display_menu
    case $choice in
        1)
            update_upgrade
            ;;
        2)
            install_default_packages
            ;;
        3)
            setup_user
            ;;
        4)
            setup_sudo
            ;;
        5)
            configure_ssh
            ;;
        6)
            setup_firewall
            ;;
        7)
            install_dev_tools
            ;;
        8)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid choice! Please select a valid option."
            ;;
    esac
    echo ""
done

echo "Bootstrap completed."
