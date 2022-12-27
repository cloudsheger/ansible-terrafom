#!/bin/bash
set +x; 

function configure_ntpServer {

    if [[ ! -z "$NTP_SERVER" ]]
      then
        mv /etc/chrony.conf /etc/chrony.conf.bak 
        echo "server $NTP_SERVER iburst" > /etc/chrony.conf
        echo "driftfile /var/lib/chrony/drift" >> /etc/chrony.conf
        echo "makestep 1.0 3" >> /etc/chrony.conf
        echo "rtcsync" >> /etc/chrony.conf
        echo "logdir /var/log/chrony" >> /etc/chrony.conf
                
        systemctl restart chronyd
    fi
}

###########################################
### AWS VARS
###########################################
echo -e "#####################################################"
echo -e "\n#### Starting bootstrap.sh at: $(date)\n"
echo -e "\n#### whoami: $(whoami)\n"
echo -e "#####################################################"

SECONDS=0
DATE=$(date "+%Y%m%d_%H%M")
INTERNAL_IP=$(curl -f http://169.254.169.254/latest/meta-data/local-ipv4)
source /etc/cfn/params

###########################################
### EXTEND VOLS
###########################################
echo -e "\n#### Extending Volumes ###\n"

echo -e "\n#### Growing part"
ROOT_VOL=$(lsblk --noheading | grep disk | awk '{print $1}' | sort | head -1)
growpart /dev/$ROOT_VOL 2

PV=$(pvs --noheading | awk '{print $1}' | sort | head -1)
VG=$(pvs --noheading | awk '{print $2}' | sort | head -1)

pvresize $PV

echo -e "\n #### Expanding vols"
lvextend --resizefs --size +40G /dev/mapper/$VG-homeVol
lvextend --resizefs --size +40G /dev/mapper/$VG-rootVol

PV_FREE=$(pvs --noheading | awk '{print $6}' | cut -f1 -d'.')
echo -n "Extending varVol by: $PV_FREE GB"
lvextend --resizefs --size '+'$PV_FREE'G' /dev/mapper/$VG-varVol

###########################################
### ADD DEVDESKTOP USER
###########################################
echo -e "\n#### Adding DevDesktop user and SSH Keys ###\n"
useradd "${DEVDESKTOP_USERNAME}" -d "/home/${DEVDESKTOP_USERNAME}" \
    -s /bin/bash -G maintuser

## Configure NTP
configure_ntpServer


if [[ $(id "${DEVDESKTOP_USERNAME}" >/dev/null 2>&1)$? -eq 0 ]]; then
    mkdir -p /home/${DEVDESKTOP_USERNAME}/.ssh
    mkdir -p /home/${DEVDESKTOP_USERNAME}/tools
    touch /home/${DEVDESKTOP_USERNAME}/.ssh/authorized_keys        
    chmod 700 /home/${DEVDESKTOP_USERNAME}/.ssh/
    chmod 600 /home/${DEVDESKTOP_USERNAME}/.ssh/authorized_keys
    chown -R ${DEVDESKTOP_USERNAME}:${DEVDESKTOP_USERNAME} /home/${DEVDESKTOP_USERNAME}
fi

# Add public key (if set)
echo ${DEVDESKTOP_PUBLIC_KEY} >> /home/${DEVDESKTOP_USERNAME}/.ssh/authorized_keys

echo "$DEVDESKTOP_PASSWORD" | passwd --stdin "${DEVDESKTOP_USERNAME}"

echo "${DEVDESKTOP_USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/user_${DEVDESKTOP_USERNAME}"

###########################################
### YUM REPOS
###########################################
echo -e "\n#### Yum Repos ###\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
cd /etc/yum.repos.d/

for REPO in  ./*.repo; do
    sed -i 's|enabled=1|enabled=0|g' $REPO
    sed -i 's|enabled = 1|enabled=0|g' $REPO
done

curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/repos/artifactory.repo"

sed -i "s|__AF_USER__|$AF_USER|g" artifactory.repo
sed -i "s|__AF_PASS__|$AF_PASS|g" artifactory.repo

yum update -y

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export PATH=$PATH:/usr/local/bin

###########################################
### PIP CONFIGS
###########################################
echo -e "\n#### PIP CONFIGS ###\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
cd ~
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/repos/pypirc"
mv pypirc .pypirc

mkdir -p .pip
cd .pip
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/repos/pip.conf"
sed -i "s|__AF_USER__|$AF_USER|g" pip.conf
sed -i "s|__AF_PASS__|$AF_PASS|g" pip.conf

###########################################
### WATCHMAKER
###########################################
echo -e "\n#### WATCHMAKER ###\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"

mkdir -p /var/log/watchmaker
echo -e "\n #### Installing Watchmaker Deps\n"
python3 -m ensurepip --upgrade --default-pip
python3 -m pip install --upgrade pip setuptools boto3
python3 -m pip install --upgrade watchmaker

echo -e "\n #### Running Watchmaker \n"
echo -e "\n #### Logs are output to: /var/log/watchmaker \n"
watchmaker -n -l error -e DEV -A $DEVDESKTOP_USERNAME -t $HOSTNAME -c $WAM_CONFIG --exclude-states join-domain*

## Preserving the hostname
echo 'preserve_hostname: true' >> /etc/cloud/cloud.cfg

###########################################
### TOOLS
###########################################
echo -e "\n#### TOOLS ###\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"

### SELINUX
echo -e "\n #### Allowing use of yum inside docker containers \n"
setenforce 0
sed -i '/^SELINUX=/s/enforcing/permissive/' /etc/selinux/config

firewall-cmd --permanent --zone=public --add-port=3389/tcp --permanent
systemctl restart firewalld

# Firefox
echo -e "\n #### Firefox ####\n"
yum install -y firefox

### Set Homepage
cp /usr/lib64/firefox/defaults/preferences/all-redhat.js \
    /usr/lib64/firefox/defaults/preferences/all-redhat.js.bak

sed -i "s|http://www.centos.org|$HOMEPAGE|g" \
    /usr/lib64/firefox/defaults/preferences/all-redhat.js

sed -i "s|file:///usr/share/doc/HTML/index.html|$HOMEPAGE|g" \
    /usr/lib64/firefox/defaults/preferences/all-redhat.js

sed -i "s|pref(\"geo.wifi.uri\"|// pref(\"geo.wifi.uri\"|g" \
    /usr/lib64/firefox/defaults/preferences/all-redhat.js

echo -e "\n\n######### DEV TOOLS and GNOME ###########\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"

yum install -y flatpak-1.0.9-9.el7_7

yum groupinstall -y "Development Tools"
yum groupinstall -y --exclude "centos-indexhtml" \
    --exclude "flatpak-libs" --exclude "flatpak" \
    "GNOME Desktop"

### GNOME setup
mkdir -p /home/$DEVDESKTOP_USERNAME/.config
echo "yes" >>/home/$DEVDESKTOP_USERNAME/.config/gnome-initial-setup-done
chown -R $DEVDESKTOP_USERNAME:$DEVDESKTOP_USERNAME /home/$DEVDESKTOP_USERNAME
su $DEVDESKTOP_USERNAME -c dbus-launch gsettings set org.gnome.desktop.screensaver lock-delay 3540
systemctl disable geoclue.service
systemctl mask geoclue.service

echo -e "\n\n############# MISC-TOOLS #############\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
yum install -y postgresql postgresql-jdbc tigervnc-server yum-plugin-ovl

### DOCKER 
echo -e "\n #### Docker ####\n"
yum install -y docker-ce docker-ce-cli containerd.io
echo -e "\n### $(docker --version)\n"

echo -e "\n #### Docker-Compose ####\n"
COMPOSE_VERSION=2.6.1
curl -L https://github.com/docker/compose/releases/download/v$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
echo -e "\n### $(docker-compose --version)\n"

usermod -a -G docker $DEVDESKTOP_USERNAME
mkdir -p /var/lib/docker
chmod 711 /var/lib/docker
systemctl enable docker.service
systemctl start docker

echo -e "\n #### RPM LOCAL ####\n"

yum install -y nodejs-12.14.1-1nodesource.x86_64
yum install -y atom.x86_64 libXScrnSaver-1.2.2-6.1.el7.x86_64 redhat-lsb-core-4.1-27.el7.centos.1.x86_64
yum install -y xrdp code

echo -e "\n #### XRDP Setup ####\n"
sed -i '0,/security_layer=negotiate/s//security_layer=tls/' /etc/xrdp/xrdp.ini
sed -i '0,/ssl_protocols=TLSv1.2, TLSv1.3/s//ssl_protocols=TLSv1.1, TLSv1.2/' /etc/xrdp/xrdp.ini
sed -i '0,/#tls_ciphers=HIGH/s//tls_ciphers=FIPS:-eNULL:-aNULL/' /etc/xrdp/xrdp.ini

### This file is REQUIRED - but unsure why ?
touch /etc/xrdp/rsakeys.ini
chcon --type=bin_t /usr/sbin/xrdp
chcon --type=bin_t /usr/sbin/xrdp-sesman
systemctl enable xrdp.service
systemctl start xrdp.service

echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"

ln -sf /lib/systemd/system/runlevel5.target \
    /etc/systemd/system/default.target

TOOLS_HOME=/home/$DEVDESKTOP_USERNAME/tools

### OPENSHIFT
echo -e "\n #### Openshift \n"
curl -f -u $AF_USER:$AF_PASS -O \
    "$AF_URL/ext-proj-local/code/devdesktop/oc-4.8.tar"
tar -xf oc-4.8.tar
cp oc /bin/
chmod 555 /bin/oc

### JDK
echo -e "\n #### JDK \n"
cd $TOOLS_HOME
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/java/jdk-11.0.6_linux-x64_bin.tar.gz"
tar -xzf jdk-11.0.6_linux-x64_bin.tar.gz

curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/java/jdk-8u231-linux-x64.tar.gz"
tar xzf jdk-8u231-linux-x64.tar.gz
unlink /bin/java

### JAVA TRUSTSTORES
echo -e "\n #### Java Truststores \n"
rm -f $TOOLS_HOME/jdk1.8.0_231/jre/lib/security/cacerts
ln -s /etc/pki/java/cacerts $TOOLS_HOME/jdk1.8.0_231/jre/lib/security/cacerts

rm -f $TOOLS_HOME/jdk-11.0.6/lib/security/cacerts
ln -s /etc/pki/java/cacerts $TOOLS_HOME/jdk-11.0.6/lib/security/cacerts

### MAVEN
echo -e "\n #### Maven \n"
cd $TOOLS_HOME/
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/maven/3.3.3/apache-maven-3.3.3-bin.zip"
unzip -q apache-maven-3.3.3-bin.zip
rm -f ./apache-maven-3.3.3/conf/settings.xml

### INTELLIJ
echo -e "\n #### IntelliJ \n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
cd $TOOLS_HOME/
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/intellij/ideaIC-2019.1.3.tar.gz"
tar xzf ideaIC-2019.1.3.tar.gz

sed -i '0,/max_bpp=32/s//max_bpp=24/' /etc/xrdp/xrdp.ini
mkdir -p /home/$DEVDESKTOP_USERNAME/.IdeaIC2019.1/config
cat >>/home/$DEVDESKTOP_USERNAME/.IdeaIC2019.1/config/idea.jdk <<EOF
$TOOLS_HOME/jdk1.8.0_231
EOF

mkdir -p /home/$DEVDESKTOP_USERNAME/.local/share/applications
cat >>/home/$DEVDESKTOP_USERNAME/.local/share/applications/jetbrains-idea-ce.desktop <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA Community Edition
Icon=$TOOLS_HOME/idea-IC-191.7479.19/bin/idea.svg
Exec="$TOOLS_HOME/idea-IC-191.7479.19/bin/idea.sh" %f
Comment=Capable and Ergonomic IDE for JVM
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea-ce
EOF

### ANACONDA
echo -e "\n #### Anaconda \n"
cd $TOOLS_HOME/
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/anaconda/Anaconda3-2019.07-Linux-x86_64.sh"
mkdir -p ../tmp
chown $DEVDESKTOP_USERNAME:$DEVDESKTOP_USERNAME /home/$DEVDESKTOP_USERNAME/tmp
export TMPDIR=/home/$DEVDESKTOP_USERNAME/tmp
chmod 750 Anaconda3-2019.07-Linux-x86_64.sh
./Anaconda3-2019.07-Linux-x86_64.sh -b -p anaconda3

##################################################
### PROFILE
##################################################
echo -e "\n #### CODE Profile \n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"

### MAVEN SETTINGS
echo -e "\n #### MAVEN SETTINGS \n"
mkdir /home/$DEVDESKTOP_USERNAME/.m2
cd /home/$DEVDESKTOP_USERNAME/.m2
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/repos/settings.xml"
sed -i "s|__AF_USER__|$AF_USER|g" settings.xml
sed -i "s|__AF_PASS__|$AF_PASS|g" settings.xml
chmod 555 /home/$DEVDESKTOP_USERNAME/.m2/settings.xml

### PIP CONFIGS
echo -e "\n #### PIP CONFIGS \n"
cp ~/.pypirc /home/$DEVDESKTOP_USERNAME/
mkdir /home/$DEVDESKTOP_USERNAME/.pip
cp ~/.pip/pip.conf /home/$DEVDESKTOP_USERNAME/.pip/

### CONDARC
echo -e "\n #### CONDARC \n"
cd /home/$DEVDESKTOP_USERNAME
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/repos/condarc"
sed -i "s|_AF_USER|$AF_USER|g" condarc
sed -i "s|AF_PASS_|$AF_PASS|g" condarc
mv condarc .condarc

### NVM
echo -e "\n #### NVM \n"
export NVM_DIR="/home/$DEVDESKTOP_USERNAME/.nvm"
mkdir $NVM_DIR
chown $DEVDESKTOP_USERNAME:$DEVDESKTOP_USERNAME $NVM_DIR
cd $NVM_DIR
su $DEVDESKTOP_USERNAME -c "wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh"
chmod 755 install.sh
su $DEVDESKTOP_USERNAME -c ./install.sh

### NPMRC
echo -e "\n #### NPMRC \n"
curl -f -u $AF_USER:$AF_PASS $AF_URL/api/npm/auth \
    > /home/$DEVDESKTOP_USERNAME/.npmrc
echo "registry=$AF_URL/api/npm/npm/" >> /home/$DEVDESKTOP_USERNAME/.npmrc
echo "cafile=/etc/pki/tls/certs/ca-bundle.crt" >> /home/$DEVDESKTOP_USERNAME/.npmrc

### NUGET CONFIG
echo -e "\n #### NUGET \n"
mkdir -p /home/$DEVDESKTOP_USERNAME/.nuget/NuGet/
cd /home/$DEVDESKTOP_USERNAME/.nuget/NuGet/
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/$AF_REPO/repos/NuGet.Config"
sed -i "s|__AF_USER__|$AF_USER|g" NuGet.Config
sed -i "s|__AF_PASS__|$AF_PASS|g" NuGet.Config

### PATH
echo -e "\n #### PATH \n"
echo -e "\nexport DEVDESKTOP_USERNAME=$DEVDESKTOP_USERNAME" >>/etc/profile
echo -e "\nexport TOOLS_HOME=/home/$DEVDESKTOP_USERNAME/tools" >>/etc/profile
echo -e "\nexport TMPDIR=/home/$DEVDESKTOP_USERNAME/tmp" >>/etc/profile
echo -e "\nexport JAVA_HOME=$TOOLS_HOME/jdk1.8.0_231" >>/etc/profile
echo -e "\nexport ANACONDA_HOME=$TOOLS_HOME/anaconda3" >>/etc/profile

PATH=$PATH:$TOOLS_HOME/jdk1.8.0_231/bin
PATH=$PATH:$TOOLS_HOME/apache-maven-3.3.3/bin
PATH=$PATH:$TOOLS_HOME/idea-IC-191.7479.19/bin
PATH=$PATH:$TOOLS_HOME/anaconda3/bin

echo -e "\nexport PATH=$PATH" >>/etc/profile
echo -e '\nREQUESTS_CA_BUNDLE="/etc/pki/tls/certs/ca-bundle.crt"' >> /etc/profile
echo -e '\nCURL_CA_BUNDLE="/etc/pki/tls/certs/ca-bundle.crt"' >> /etc/profile

##################################################
### ADO Tools
##################################################
echo -e "\n #### ADO Tools ####\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
yum install -y gcc zlib-devel bzip2-devel \
    readline-devel sqlite-devel openssl-devel \
    libffi-devel python3-devel openldap-devel \
    gcc-c++ libpng libtiff terminator jq dnf

# Disable LDAP (DIMEOPS-2842)
authconfig --disableldapauth --disableldap --enableshadow --updateall

# Slack
echo -e "\n #### Slack ####\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
yum install -y --nogpgcheck https://downloads.slack-edge.com/releases/linux/4.25.0/prod/x64/slack-4.25.0-0.1.fc21.x86_64.rpm

# Chrome
echo -e "\n #### Chrome ####\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm -O $TOOLS_HOME/google-chrome-stable_current_x86_64.rpm
yum localinstall -y --nogpgcheck $TOOLS_HOME/google-chrome-stable_current_x86_64.rpm

# MEME Test Certificates
echo -e "\n #### MEME Test Certs ####\n"
cd $TOOLS_HOME
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/ext-proj-local/ado/devdesktop/MEME_Tester_Certs.tar.gz"
tar -xvf MEME_Tester_Certs.tar.gz

# Git
echo -e "\n #### Git 2.36 ####\n"
yum install -y epel-release
yum remove -y git
yum install -y --nogpgcheck  https://repo.ius.io/ius-release-el7.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y git236

# Pycharm
echo -e "\n #### Pycharm Community ####\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
yum install -y pycharm-community
cp /usr/share/applications/pycharm-community.desktop /home/$DEVDESKTOP_USERNAME/.local/share/applications/
chown -R $DEVDESKTOP_USERNAME:$DEVDESKTOP_USERNAME /home/$DEVDESKTOP_USERNAME/.local/share/applications/

# Pyenv
echo -e "\n #### Pyenv ####\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
git clone https://github.com/yyuu/pyenv.git /home/$DEVDESKTOP_USERNAME/.pyenv
chown -R $DEVDESKTOP_USERNAME:$DEVDESKTOP_USERNAME /home/$DEVDESKTOP_USERNAME/.pyenv
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> /home/$DEVDESKTOP_USERNAME/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/$DEVDESKTOP_USERNAME/.bashrc
echo 'eval "$(pyenv init -)"' >> /home/$DEVDESKTOP_USERNAME/.bashrc

# Postman
echo -e "\n #### Postman ####\n"
echo -e "#### $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds elapsed\n"
wget https://dl.pstmn.io/download/latest/linux64 -O $TOOLS_HOME/postman.tar.gz
cd $TOOLS_HOME
tar -xvf $TOOLS_HOME/postman.tar.gz
cat >>/home/$DEVDESKTOP_USERNAME/.local/share/applications/Postman.desktop <<EOF
[Desktop Entry]
Encoding=UTF-8
Name=Postman
Exec=$TOOLS_HOME/Postman/app/Postman %U
Icon=$TOOLS_HOME/Postman/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;
EOF

# Helm
echo -e "\n #### Helm ####\n"
cd $TOOLS_HOME
curl -f -u $AF_USER:$AF_PASS -O "$AF_URL/ext-proj-local/ado/devdesktop/helm-v3.9.0-linux-amd64.tar.gz"
mkdir -p $TOOLS_HOME/helm
tar -xvf $TOOLS_HOME/helm-v3.9.0-linux-amd64.tar.gz -C $TOOLS_HOME/helm
cp $TOOLS_HOME/helm/linux-amd64/helm /usr/local/bin/helm

# Transcrypt
echo -e "\n #### Transcrypt ####\n"
cd $TOOLS_HOME
git clone https://github.com/elasticdog/transcrypt.git
cd transcrypt/
ln -s ${PWD}/transcrypt /usr/local/bin/transcrypt

# Elasticsearch Container Updates
echo "" >> /etc/sysctl.conf
echo "# ADO Update for running Elasticsearch continer" >> /etc/sysctl.conf
echo -n "vm.max_map_count = 262144" >> /etc/sysctl.conf

# Increase Max User Watches
echo "" >> /etc/sysctl.conf
echo "# ADO Update for increasing max user watches (See DIMEOPS-2949)" >> /etc/sysctl.conf
echo -n "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf

##################################################
### CLEANUP
##################################################
echo -e "\n #### Cleanup \n"
cd $TOOLS_HOME/
mkdir -p backup
mv *.gz *.zip *.sh *.rpm backup/
chown -R $DEVDESKTOP_USERNAME:$DEVDESKTOP_USERNAME /home/$DEVDESKTOP_USERNAME

echo -e "#####################################################"
echo -e "#### DONE!"
echo -e "#### Completed bootstrap.sh at: $(date)\n"
echo -e "#### Total time: $(($SECONDS / 60)) minutes $(($SECONDS % 60)) seconds"
echo -e "#### Rebooting DevDesktop instance..."
echo -e "#####################################################"

##################################################
### REBOOT
##################################################
shutdown -r +1 &
