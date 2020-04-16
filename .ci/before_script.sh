#!/bin/bash

# got from https://blogs.itemis.com/en/secure-your-travis-ci-releases-part-2-signature-with-openpgp

end_with_error()
{
 echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
 exit 1
}

declare -r custom_gpg_home="./.ci"
declare -r secring_auto="${custom_gpg_home}/secring.auto"
declare -r pubring_auto="${custom_gpg_home}/pubring.auto"

echo
echo "Decrypting secret gpg keyring.."
# $super_secret_password is taken from the script's env. See below in the blog.
{ echo $super_secret_password | gpg --batch --yes --skip-verify --passphrase-fd 0 --output "${secring_auto}" -d "${secring_auto}".gpg ; } || { end_with_error "Failed to decrypt secret gpg keyring." ; }
echo Success!

echo "Decrypting secret ssh key.."
# $super_secret_password is taken from the script's env. See below in the blog.
{ echo $super_secret_password | gpg --batch --yes --skip-verify --passphrase-fd 0 --output .ci/id_dsa -d .ci/id_dsa.gpg ; } || { end_with_error "Failed to decrypt secret ssh key." ; }
chmod 600 .ci/id_dsa || { end_with_error "Failed to decrypt secret ssh key." ; }
echo Success!

echo
echo Importing keyrings..
{ gpg --import "${secring_auto}" ; } || { end_with_error "Could not import secret keyring into gpg." ; }
{ gpg --import "${pubring_auto}" ; } || { end_with_error "Could not import public keyring into gpg." ; }

mkdir -p $HOME/.ssh/
chmod 700 $HOME/.ssh/
ssh-keyscan ppa.launchpad.net >> $HOME/.ssh/known_hosts
echo "StrictHostKeyChecking no" >> $HOME/.ssh/config
echo "IdentityFile $(pwd)/.ci/id_dsa" >> $HOME/.ssh/config
echo "PubkeyAuthentication yes" >> $HOME/.ssh/config
echo "IdentitiesOnly yes" >> $HOME/.ssh/config
echo "BatchMode yes" >> $HOME/.ssh/config
echo "ConnectionAttempts 2" >> $HOME/.ssh/config
echo "PasswordAuthentication no" >> $HOME/.ssh/config
echo "PubkeyAcceptedKeyTypes +ssh-dss" >> $HOME/.ssh/config

echo Success!
