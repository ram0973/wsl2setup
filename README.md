# Development environment for Python/Django/etc in Windows10 with WSL2, Docker, Fabric, SSL certificates, systemd enabled

## Install software, if needed:

Install [Pycharm](https://www.jetbrains.com/pycharm/)  (Python IDE)  
Install [PgAdmin](https://www.pgadmin.org/)  (Postgresql utility)  
Install [MkCert](https://github.com/FiloSottile/mkcert)  (Local certificates generator)  

You can install all of this via [Choco](https://https://chocolatey.org/install/) and Powershell:
(But don't mix manual installed programs with programs installed with choco):

1. Run Powershell with admin privileges  
2. Install Choco, if not already:  
```powershell
PS> Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```
3. Install software:
```powershell
PS> choco install powershell-core pycharm pgadmin4 mkcert git microsoft-windows-terminal -y
```
4. (Optional) Install  [OhMyPosh](https://www.hanselman.com/blog/HowToMakeAPrettyPromptInWindowsTerminalWithPowerlineNerdFontsCascadiaCodeWSLAndOhmyposh.aspx)


## Prepare app sources folder
```powershell
PS> mkdir d:\webapps
PS> cd d:\webapps
PS> git clone your_application app_name
```

## Add local development root certificates to trusted store:
```powershell
# Look for local CA certificates path:
PS> mkcert -CAROOT
%USERPROFILE%\AppData\Local\mkcert
# Go to d:\webapps\app_name and run:
PS> Copy-Item -Path ".\fabric\local_certs\rootCA-key.pem" -Destination "C:\Users\user_name\AppData\Local\mkcert\rootCA-key.pem"
PS> Copy-Item -Path ".\fabric\local_certs\chain.pem" -Destination "C:\Users\user_name\AppData\Local\mkcert\rootCA.pem"
PS> mkcert -install
```

## Install WSL 2:
```powershell
Check is WSL exists:
PS> wsl
Install WSL subsystem, if not installed:
PS> dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
PS> dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

Restart Windows.  
Install Ubuntu from [Microsoft store](https://www.microsoft.com/ru-ru/search/shop/Apps?q=ubuntu)  
Install only Ubuntu, with no suffix, because other, e.g. Ubuntu 20.04, Pycharm will not recognize
  
Run WSL:
```powershell
PS> wsl --set-default-version 2
PS> wsl
```

## Passwordless sudo
```bash  
cat <<-'EOF' | sudo tee -a /etc/sudoers.d/sudo
%sudo         ALL = (ALL) NOPASSWD: ALL
EOF
```

## Get systemd functional in WSL2. 
Ubuntu 20.04 tested only. In previuous versions daemonize stays at another path, please check yours.
Thanks to [this tutorial](https://hoverbear.org/blog/getting-the-most-out-of-wsl/)

```bash
sudo apt-get update
sudo apt-get install -yqq daemonize dbus-user-session
cat <<-'EOF' | sudo tee -a /usr/sbin/start-systemd-namespace > /dev/null
#!/bin/bash

SYSTEMD_PID=$(ps -ef | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')
if [ -z "$SYSTEMD_PID" ] || [ "$SYSTEMD_PID" != "1" ]; then
    export PRE_NAMESPACE_PATH="$PATH"
    (set -o posix; set) | \
        grep -v "^BASH" | \
        grep -v "^DIRSTACK=" | \
        grep -v "^EUID=" | \
        grep -v "^GROUPS=" | \
        grep -v "^HOME=" | \
        grep -v "^HOSTNAME=" | \
        grep -v "^HOSTTYPE=" | \
        grep -v "^IFS='.*"$'\n'"'" | \
        grep -v "^LANG=" | \
        grep -v "^LOGNAME=" | \
        grep -v "^MACHTYPE=" | \
        grep -v "^NAME=" | \
        grep -v "^OPTERR=" | \
        grep -v "^OPTIND=" | \
        grep -v "^OSTYPE=" | \
        grep -v "^PIPESTATUS=" | \
        grep -v "^POSIXLY_CORRECT=" | \
        grep -v "^PPID=" | \
        grep -v "^PS1=" | \
        grep -v "^PS4=" | \
        grep -v "^SHELL=" | \
        grep -v "^SHELLOPTS=" | \
        grep -v "^SHLVL=" | \
        grep -v "^SYSTEMD_PID=" | \
        grep -v "^UID=" | \
        grep -v "^USER=" | \
        grep -v "^_=" | \
        cat - > "$HOME/.systemd-env"
    echo "PATH='$PATH'" >> "$HOME/.systemd-env"
    exec sudo /usr/sbin/enter-systemd-namespace "$BASH_EXECUTION_STRING"
fi
if [ -n "$PRE_NAMESPACE_PATH" ]; then
    export PATH="$PRE_NAMESPACE_PATH"
fi
EOF

sudo chmod +x /usr/sbin/start-systemd-namespace

cat <<-'EOF' | sudo tee -a /usr/sbin/enter-systemd-namespace > /dev/null
#!/bin/bash

if [ "$UID" != 0 ]; then
    echo "You need to run $0 through sudo"
    exit 1
fi

SYSTEMD_PID="$(ps -ef | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')"
if [ -z "$SYSTEMD_PID" ]; then
    /usr/bin/daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target
    while [ -z "$SYSTEMD_PID" ]; do
        SYSTEMD_PID="$(ps -ef | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')"
    done
fi

if [ -n "$SYSTEMD_PID" ] && [ "$SYSTEMD_PID" != "1" ]; then
    if [ -n "$1" ] && [ "$1" != "bash --login" ] && [ "$1" != "/bin/bash --login" ]; then
        exec /usr/bin/nsenter -t "$SYSTEMD_PID" -a \
            /usr/bin/sudo -H -u "$SUDO_USER" \
            /bin/bash -c 'set -a; source "$HOME/.systemd-env"; set +a; exec bash -c '"$(printf "%q" "$@")"
    else
        exec /usr/bin/nsenter -t "$SYSTEMD_PID" -a \
            /bin/login -p -f "$SUDO_USER" \
            $(/bin/cat "$HOME/.systemd-env" | grep -v "^PATH=")
    fi
    echo "Existential crisis"
fi
EOF

sudo chmod +x /usr/sbin/enter-systemd-namespace

cat <<-'EOF' | sudo tee -a /etc/sudoers.d/wsl > /dev/null
Defaults        env_keep += WSLPATH
Defaults        env_keep += WSLENV
Defaults        env_keep += WSL_INTEROP
Defaults        env_keep += WSL_DISTRO_NAME
Defaults        env_keep += PRE_NAMESPACE_PATH
%sudo ALL=(ALL) NOPASSWD: /usr/sbin/enter-systemd-namespace
EOF

sudo sed -i 2a"# Start or enter a PID namespace in WSL2\nsource /usr/sbin/start-systemd-namespace\n" /etc/bash.bashrc

```
And in powershell:  
```powershell
PS> cmd.exe /C setx WSLENV BASH_ENV/u  
PS> cmd.exe /C setx BASH_ENV /etc/bash.bashrc  
PS> wsl --shutdown  
```

## Setup SSH keys
```bash
# You must already setup your environment,
# for example, https://github.com/ram0973/dotfiles

# check existing ssh keys
$ ls -al ~/.ssh
# create key if needed, skip this step if existed:
$ ssh-keygen -t rsa -b 4096 -C "your_mail@your_domain"
# or copy your key to ~/.ssh if existed in Windows
$ mkdir -p ~/.ssh
# cp -r /mnt/c/Users/user_name/.ssh/* ~/.ssh/
# chmod -R o-rwx,g-rwx ~/.ssh/*
# change passphrase if desired: 
$ ssh-keygen -p
```

## Install ssh agent:
```bash
# Ssh-agent: add next two lines to ~/.bashrc
$ eval "$(ssh-agent -s)"
$ ssh-add ~/.ssh/id_rsa
$ . ~/.bashrc
```

## Prepare github keys:
```bash
# Go to github and paste contents of ~/.id_rsa.pub there https://github.com/settings/ssh/new
# Test key on github
$ ssh -T git@github.com
```

## Prepare ssh config
Write in ~/.ssh/config:
```
Host dev
  Hostname localhost
  Port 22
  User user_name
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
Host prod
  Hostname production_server_name
  Port ssh_port_on_production
  User user_name
  IdentityFile ~/.ssh/id_rsa
```

## Prepare local OpenSSH server
```bash
$ which sshd
# Answer: /usr/sbin/sshd
$ /usr/sbin/sshd
# sshd: no hostkeys available -- exiting.
$ sudo ssh-keygen -A
$ sudo sed -i 's|[#]*PasswordAuthentication no|PasswordAuthentication yes|g' /etc/ssh/sshd_config
$ sudo systemctl enable ssh
$ sudo systemctl restart ssh
$ ssh-copy-id -i ~/.ssh/id_rsa.pub dev
# check:
$ ssh dev
$ exit

``` 

## Prepare working folder
```bash
$ sudo ln -sf /mnt/d/webapps/ /webapps 
$ cd /webapps/app_name
```

## Prepare dependencies
```bash
Install pyenv
$ make pyenv
# restart shell, then
pyenv install 3.8.2
pyenv local 3.8.2
Install poetry
$ make poetry 
```

## Configure Pycharm

<details><summary>View screenshots</summary>
<img src="https://github.com/ram0973/wsl2setuo/blob/master/screenshots/vagrant_sftp_connection.png" width="597" height="504">
</details>

Pycharm: configure deployment to Vagrant virtual machine:

1. Check hosts in %USERPROFILE\.ssh\known_hosts or simply delete it.

poetry run which python
WSL2: /home/$USER/.cache/pypoetry/virtualenvs/rma-q7cYQMLp-py3.8/bin/python
configure SSH interpreter


**Tools - Deployment - Configuration**:

Connection type: SFTP;
SFTP host: 127.0.0.1; Port: 22; User name: user_name;
Authentication: key pair;
Deployment path: /webapps/djblog;
Excluded: venv, .idea, .vagrant

**Tools - Deployment - Automatic uploads**: always.

## Database inspection with pgadmin4

1) Open [pgadmin4](https://www.pgadmin.org/)
2) Create server with settings:
Server: localhost
Port: 5432
User: postgres
Password: postgres

## Postgresql psql console command
```bash
$ sudo -u postgres psql djblog
```
```psql
djblog=# \a # aligned/unaligned format
djblog=# \c database_name # connect to database
djblog=# \h # help
djblog=# \l # list databases
djblog=# \d # list relations (tables/sequnces)
djblog=# \du # list user roles
# IMPORTANT: user postgres MUST be SUPERUSER
djblog=# \z # list privileges
# IMPORTANT: CREATEDB - for tests, LOGIN - for migrations
# https://www.postgresql.org/docs/current/sql-grant.html
djblog=# select * from accounts_user; # show users
djblog=# \q # quit
```

## Optional: How to create your own SSL certificates for local development
We will use https://github.com/FiloSottile/mkcert and openssl:
```
PS> choco install mkcert openssl
# Create and install root certificate
PS> mkcert -install
PS> mkdir d:\certs
PS> cd d:\certs
# Create localhost certificate
PS> mkcert localhost
# Create SSL-dhparams certificate:
# you can also add  C:\Program Files\OpenSSL-Win64\bin to PATH, restart shell
PS> C:\"Program Files"\OpenSSL-Win64\bin\openssl dhparam -out d:\certs\ssl-dhparams.pem 2048
```
Root certificate will be at c:\\Users\\%username%\\AppData\\Local\\mkcert\\
rootCA-key.pem -> copy to d:\certs
rootCA.pem -> copy to d:\certs and rename to chain.pem

Localhost certificates:
d:\certs\localhost-key.pem -> rename to privkey.pem
d:\certs\localhost.pem -> rename to fullchain.pem

## License
[MIT](http://opensource.org/licenses/MIT) 
