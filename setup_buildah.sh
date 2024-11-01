#!/bin/bash


# Function to install on Arch Linux
install_arch() {
    echo "Installing Buildah on Arch Linux using pacman..."
    sudo pacman -S buildah
}

# Function to install on CentOS
install_centos() {
    echo "Installing Buildah on CentOS using yum..."
    sudo yum -y install buildah
}

# Function to install on Debian
install_debian() {
    echo "Installing Buildah on Debian using apt-get..."
    sudo apt-get update
    sudo apt-get -y install buildah
}

# Function to install on Fedora
install_fedora() {
    echo "Installing Buildah on Fedora using dnf..."
    sudo dnf -y install buildah
}

# Function to install on Fedora SilverBlue
install_fedora_silverblue() {
    echo "Buildah is installed by default on Fedora SilverBlue."
}

# Function to install on Fedora CoreOS
install_fedora_coreos() {
    echo "Installing Buildah on Fedora CoreOS using rpm-ostree (package layering)..."
    rpm-ostree install buildah
}

# Function to install on Gentoo
install_gentoo() {
    echo "Installing Buildah on Gentoo using emerge..."
    sudo emerge app-containers/buildah
}

# Function to install on openSUSE
install_opensuse() {
    echo "Installing Buildah on openSUSE using zypper..."
    sudo zypper install buildah
}

# Function to install on openSUSE Kubic
install_opensuse_kubic() {
    echo "Installing Buildah on openSUSE Kubic using transactional-update..."
    transactional-update pkg in buildah
}

# Function to install on RHEL 7
install_rhel7() {
    echo "Installing Buildah on RHEL 7. Ensuring subscription and enabling the Extras channel..."
    sudo subscription-manager repos --enable=rhel-7-server-extras-rpms
    sudo yum -y install buildah
}

# Function to install on RHEL 8 Beta
install_rhel8_beta() {
    echo "Installing Buildah on RHEL 8 Beta..."
    sudo yum module enable -y container-tools:1.0
    sudo yum module install -y buildah
}

# Function to install on Ubuntu
install_ubuntu() {
    echo "Installing Buildah on Ubuntu using apt-get..."
    sudo apt-get -y update
    sudo apt-get -y install buildah
}

# Function to manually install Buildah
manual_install() {
    echo "Manual installation of Buildah is required for your system."
    
    # Install packages providing newuidmap and newgidmap
    echo "Installing necessary packages for newuidmap and newgidmap..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y uidmap
    elif command -v yum &> /dev/null; then
        sudo yum install -y shadow-utils
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y shadow
    else
        echo "Please install newuidmap and newgidmap manually for your distribution."
        exit 1
    fi

    # Ensure correct capabilities for newuidmap and newgidmap
    echo "Setting capabilities for newuidmap and newgidmap..."
    sudo setcap cap_setuid+ep /usr/bin/newuidmap
    sudo setcap cap_setgid+ep /usr/bin/newgidmap
    sudo chmod u-s,g-s /usr/bin/newuidmap /usr/bin/newgidmap

    # Ensure /etc/subuid and /etc/subgid files exist
    echo "Checking /etc/subuid and /etc/subgid..."
    if [ ! -f /etc/subuid ] || [ ! -f /etc/subgid ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y login
        elif command -v yum &> /dev/null ]; then
            sudo yum install -y shadow-utils
        elif command -v zypper &> /dev/null; then
            sudo zypper install -y shadow
        else
            echo "Please ensure /etc/subuid and /etc/subgid are correctly set up."
            exit 1
        fi
    fi

    # Add an entry to /etc/subuid and /etc/subgid
    echo "Configuring /etc/subuid and /etc/subgid for user $CURRENT_USER..."
    if ! grep -q "$CURRENT_USER" /etc/subuid; then
        echo "$CURRENT_USER:1000000:65536" | sudo tee -a /etc/subuid
    fi
    if ! grep -q "$CURRENT_USER" /etc/subgid; then
        echo "$CURRENT_USER:1000000:65536" | sudo tee -a /etc/subgid
    fi

    echo "Manual configuration complete. You may need to reboot your system for changes to take full effect."
}

# Get the current user's name
CURRENT_USER=$(whoami)

# Detect OS and install Buildah
if grep -i "arch" /etc/*release; then
    install_arch
elif grep -i "centos" /etc/*release; then
    install_centos
elif grep -i "debian" /etc/*release; then
    install_debian
elif grep -i "fedora" /etc/*release && ! grep -qi "coreos" /etc/*release && ! grep -qi "silverblue" /etc/*release; then
    install_fedora
elif grep -i "fedora" /etc/*release && grep -qi "silverblue" /etc/*release; then
    install_fedora_silverblue
elif grep -i "fedora" /etc/*release && grep -qi "coreos" /etc/*release; then
    install_fedora_coreos
elif grep -i "gentoo" /etc/*release; then
    install_gentoo
elif grep -i "suse" /etc/*release; then
    if grep -qi "kubic" /etc/*release; then
        install_opensuse_kubic
    else
        install_opensuse
    fi
elif grep -i "red hat" /etc/*release && grep -q "release 7" /etc/*release; then
    install_rhel7
elif grep -i "red hat" /etc/*release && grep -q "release 8" /etc/*release; then
    install_rhel8_beta
elif grep -i "ubuntu" /etc/*release; then
    install_ubuntu
else
    echo "Attempting manual installation of Buildah..."
    manual_install
fi



# Create the path /home/<current user>/.local/share/containers if it doesn't exist
CONTAINER_PATH="/home/${CURRENT_USER}/.local/share/containers"
if [ ! -d "$CONTAINER_PATH" ]; then
  mkdir -p "$CONTAINER_PATH"
  echo "Created directory: $CONTAINER_PATH"
fi

# Ensure the current user has read and write access to the directory
chmod u+rw "$CONTAINER_PATH"
echo "Set read and write permissions for $CURRENT_USER in $CONTAINER_PATH"

# Check the sysctl value: kernel.unprivileged_userns_clone
KERNEL_SETTING=$(sysctl -ne kernel.unprivileged_userns_clone)
if [ "$KERNEL_SETTING" -eq 0 ]; then
  echo 'kernel.unprivileged_userns_clone = 1' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  echo "Updated kernel.unprivileged_userns_clone value"
fi

# Check the sysctl value: user.max_user_namespaces
USER_NAMESPACES_SETTING=$(sysctl -n user.max_user_namespaces)
if [ "$USER_NAMESPACES_SETTING" -lt 15000 ]; then
  echo 'user.max_user_namespaces = 15000' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  echo "Updated user.max_user_namespaces value"
fi
