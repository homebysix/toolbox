#!/bin/bash

set -o pipefail

if [[ ! -e ~/.docker/machine/.toolboxsetupdone ]]; then
  
  MYUID=$(/usr/bin/id -u)
  MYGID=$(/usr/bin/id -g)

  # Place boot2docker ISO in cache
  if [[ ! -d ~/.docker/machine/cache ]]; then
    mkdir -p ~/.docker/machine/cache
  fi

  if [[ ! -e ~/.docker/machine/cache/boot2docker.iso ]]; then
      cp /usr/local/share/boot2docker/boot2docker.iso ~/.docker/machine/cache/boot2docker.iso
      chown -R $MYUID:$MYGID ~/.docker
  fi

  # Fix permissions on binaries
  # chown -R $MYUID:admin /usr/local/bin/docker
  # chown -R $MYUID:admin /usr/local/bin/docker-machine
  # chown -R $MYUID:admin /usr/local/bin/docker-compose
  # chown -R $MYUID:admin /usr/local/bin/docker-toolbox-setup.sh

  # Migrate Boot2Docker VM if VirtualBox is installed
  BOOT2DOCKER_VM=boot2docker-vm
  VM=default

  VBOXMANAGE=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage

  # Make sure this version of boot2docker can migrate
  /usr/local/bin/docker-machine create --help | grep virtualbox-import-boot2docker-vm
  DOCKER_MACHINE_MIGRATION_CHECK=$?

  if [ -f $VBOXMANAGE ] && [ -f /usr/local/bin/docker-machine ] && [ $DOCKER_MACHINE_MIGRATION_CHECK -eq 0 ]; then
    sudo -u $MYUID $VBOXMANAGE showvminfo $BOOT2DOCKER_VM &> /dev/null
    BOOT2DOCKER_VM_EXISTS_CODE=$?

    sudo -u $MYUID $VBOXMANAGE showvminfo $VM &> /dev/null
    VM_EXISTS_CODE=$?

    # Exit if there's no boot2docker vm, or the destination VM already exists
    if [ $BOOT2DOCKER_VM_EXISTS_CODE -eq 0 ] && [ $VM_EXISTS_CODE -ne 0 ]; then
      # Prompt the user to migrate
      osascript -e 'tell app "System Events" to display dialog "Migrate your existing Boot2Docker VM to work with the Docker Toolbox?\n \nYour existing Boot2Docker VM will not be affected. This should take about a minute." buttons {"Do not Migrate", "Migrate"} default button 2 cancel button 1 with icon 2 with title "Migrate Boot2Docker VM?"'
      if [ $? -eq 0 ]; then

        # Clear out any existing VM data in case the user deleted the VM manually via VirtualBox
        /usr/local/bin/docker-machine rm -f $VM &> /dev/null
        rm -rf ~/.docker/machine/machines/$VM

        # Run migration, opening logs if it fails
        sudo -u $MYUID PATH=/Applications/VirtualBox.app/Contents/MacOS/:$PATH /usr/local/bin/docker-machine -D create -d virtualbox --virtualbox-import-boot2docker-vm $BOOT2DOCKER_VM $VM 2>&1 | sed -e '/BEGIN/,/END/d' > /tmp/toolbox-migration-logs.txt
        if [ $? -eq 0 ]; then
          osascript -e 'tell app "System Events" to display dialog "Boot2Docker VM migrated successfully to a Docker Machine VM named \"default\"" buttons {"Ok"} default button 1'
        else
          osascript -e 'tell app "System Events" to display dialog "Could not migrate the Boot2Docker VM. Please file an issue with the migration logs at https://github.com/docker/machine/issues/new." buttons {"Cancel", "View Migration Logs"} default button 2 cancel button 1 with icon 0  with title "Migration Failed"'
          if [ $? -eq 0 ]; then
            open -a TextEdit /tmp/toolbox-migration-logs.txt
          fi
          exit 1
        fi
      fi
    fi
  fi


  # Open Applications dir if it exists and is not empty
  if [ -d /Applications/Docker ] && [ "$(ls -A /Applications/Docker)" ]; then
    open /Applications/Docker
  fi

  touch ~/.docker/machine/.toolboxsetupdone

fi
