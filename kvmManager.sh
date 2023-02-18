#!/bin/bash

# Function to start a KVM virtual machine
start_vm() {
    vm_name=$1

    # Check if .kvmconfig exists and exit if it does not
    if [ ! -f .kvmconfig ]; then
        echo "Error: .kvmconfig not found"
        return
    fi

    # Check if the VM has a configuration in .kvmconfig
    if ! grep -q "^$vm_name|" .kvmconfig; then
        # If the VM does not exist in the config file, print an error message and exit the function
        echo "Error: no configuration found for virtual machine $vm_name"
        return
    fi

    # Read the configuration from the .kvmconfig
    vm_config=$(grep "^$vm_name|" .kvmconfig)
    vm_ram=$(echo "$vm_config" | cut -d "|" -f 2)
    vm_mac=$(echo "$vm_config" | cut -d "|" -f 3)
    hostfwd=$(echo "$vm_config" | cut -d "|" -f 4)
    hport=$(echo "$vm_config" | cut -d "|" -f 5)
    gport=$(echo "$vm_config" | cut -d "|" -f 6)
    proto=$(echo "$vm_config" | cut -d "|" -f 7)
    net=$(echo "$vm_config" | cut -d "|" -f 8)

    cmd="kvm -hda ${vm_name}.img -m ${vm_ram}M -net nic"

    if [ "$hostfwd" == "1" ]; then
        cmd="$cmd -net ${net},hostfwd=${proto}::${hport}-:${gport}"
    fi

    if [ "$br" == "y" ]; then
        cmd="$cmd macaddr=${vm_mac} -net ${net},script=no"
        eval "$cmd"
        return
    fi

    cmd="$cmd"

    eval "$cmd"

}

# Function to check the status of a KVM virtual machine
modify_vm() {
    vm_name=$1

    # Check if .kvmconfig exists and exit if it does not
    if [ ! -f .kvmconfig ]; then
        echo "Error: .kvmconfig not found"
        return
    fi

    # Check if the VM has a configuration in .kvmconfig
    if ! grep -q "^$vm_name|" .kvmconfig; then
        # If the VM does not exist in the config file, print an error message and exit the function
        echo "Error: no configuration found for virtual machine $vm_name"
        return
    fi

    # Read the configuration from the .kvmconfig
    vm_config=$(grep "^$vm_name|" .kvmconfig)
    vm_ram=$(echo "$vm_config" | cut -d "|" -f 2)
    vm_mac=$(echo "$vm_config" | cut -d "|" -f 3)
    hostfwd=$(echo "$vm_config" | cut -d "|" -f 4)
    hport=$(echo "$vm_config" | cut -d "|" -f 5)
    gport=$(echo "$vm_config" | cut -d "|" -f 6)
    proto=$(echo "$vm_config" | cut -d "|" -f 7)
    net=$(echo "$vm_config" | cut -d "|" -f 8)
    
    while true; do

        echo "The machine $vm_name has the following attributes:"
        echo "RAM(1) = $vm_ram"
        echo "MAC ADDRESS(2) = $vm_mac"
        echo "HOSTFWD flag(3) = $hostfwd"
        echo "HOST PORT(4) = $hport"
        echo "GUEST PORT(5) = $gport"
        echo "PROTOCOL(6) = $proto"
        echo "NET MODE(7) = $net"
        echo "exit(8)"

        read -p "Which one would you like to modify? (1-7)" choice
        case $choice in
            1)
                read -p "Enter the new amout of RAM: " vm_name
                ;;
            2)
                read -p "Enter the new MAC Addr: " vm_mac
                ;;
            3)
                read -p "Enter new state of HOSTFWD flag (1/0): " hostfwd
                ;;
            4)
                read -p "Change the HOST port: " hport
                ;;
            5)  read -p "Change the GUEST port: " gport
                ;;
            6)  read -p "Protocol (tcp/udp): " proto
                ;;
            7)  read -p "Change the NET mode (user/tap): " net
                ;;
            8)  echo "Modifications completed and updated"
                sed -i "/^$vm_name|/d" .kvmconfig
                echo "$vm_name|$vm_ram|$vm_mac|$hostfwd|$hport|$gport|$proto|$net" >> .kvmconfig
                return
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
    done
}

create_vm() {
    read -p "Enter the name of the new virtual machine: " vm_name

    # Get the memory and vcpu options from the user
    read -p "Enter the amount of memory for the new virtual machine (in GB): " vm_memory

    # Ask for the path to an ISO file
    read -e -p "Enter the path to an ISO file for the new virtual machine: " vm_iso_file

    # Check if .kvmconfig exists and create it if not
    if [ ! -f .kvmconfig ]; then
        touch .kvmconfig
        echo "VM NAME | RAM | MAC | HOST FORWARD | HOST PORT | GUEST PORT | PROTOCOL | NET" >> .kvmconfig
    fi

    # Check if the VM already has a configuration in .kvmconfig
    if grep -q "^$vm_name|" .kvmconfig; then
        # If the VM exists in the config file, ask the user if they want to overwrite it
        read -p "A configuration for $vm_name already exists. Do you want to overwrite it? (y/n) " overwrite

        if [ "$overwrite" != "y" ]; then
            # If the user does not want to overwrite the existing configuration, exit the function
            return
        else
            sed -i "/^$vm_name|/d" .kvmconfig
        fi
    fi

    echo "Creating a virtual disk"
    qemu-img create -f qcow2 ${vm_name}.img ${vm_memory}G

    echo "Before logging into the VM. We need to specify some parameters."
    echo "Don't worry, you can change them in a future ( check .kvmconfig for more)"

    read -p "Enter the amout of RAM for the new virtual machine (in MB): " vm_ram

    read -ei "52:54:00:12:34:56" -p "Enter the MAC address for the new virtual machine (enter for default): " vm_mac_address

    read -p "Would you like to activate host port forwarding? (y/n) " hostfwd

    proto="N.A"
    hport="N.A"
    gport="N.A"
    net="user"

    if [ "$hostfwd" == "y" ]; then
        hostfwd = 1
        echo "Protocol?(tcp/udp)"
        read proto
        echo "Host Port?"
        read hport
        echo "Guest Port?"
        read gport
    fi
    
    read -p "Would you like to connect the VM's to a Linux Bridge? (y/n) " br
    if [ "$br" == "y" ]; then
        net="tap"
    fi
    # Write the configuration to the .kvmconfig
    echo "$vm_name|$vm_ram|$vm_mac|$hostfwd|$hport|$gport|$proto|$net" >> .kvmconfig

    # Create the virtual machine

    cmd="kvm -hda ${vm_name}.img -m ${vm_ram}M -cdrom $vm_iso_file -net nic"

    if [ "$hostfwd" == "y" ]; then
        cmd="$cmd -net ${net},hostfwd=${proto}::${hport}-:${gport}"
    fi

    if [ "$br" == "y" ]; then
        cmd="$cmd macaddr=${vm_mac} -net ${net},script=no"
    fi

    cmd="$cmd -net user"

    eval "$cmd"
}

# Main menu

while true; do

    echo "Select an option:"
    echo "1. Start VM"
    echo "2. Modify VM"
    echo "3. Create VM"
    echo "4. Quit"
    read choice

    case $choice in
        1)
            echo "Enter the name of the virtual machine to start:"
            read vm_name
            start_vm $vm_name
            ;;
        2)
            echo "Enter the name of the virtual machine to modify:"
            read vm_name
            modify_vm $vm_name
            ;;
        3)
            create_vm
            ;;
        4)
            exit
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done