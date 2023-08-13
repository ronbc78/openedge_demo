#!/bin/bash

runKubectl() {
  kubectl apply -f - <<EOF
$1
EOF
}



sprint() {
  text="$1"
  delay="$2"

  # Convert the text to an array of characters (including spaces)
  characters=()
  for ((i = 0; i < ${#text}; i++)); do
    characters+=("${text:$i:1}")
  done

  # Print each character with a delay
  for char in "${characters[@]}"; do
    echo -n "$char"
    sleep "0.02" # Delay in seconds
  done

  # Print a newline at the end
  echo
}

instancesMenu() {
  while true; do
    echo -e "\nPlease choose an option:"
    echo "step 0: Provide Kubeconfig"
    echo "step 1: install kubelogin"
    echo "step 2: install kubectl"
    echo "step 3: generate ssh-keys"
    echo "step 4: kubectl get instancegroups"
    echo "step 5: kubectl get instances"
    echo "step 6: deleteInstanceGroups"
    echo "step 7: createComputeImage"
    echo "step 8: createInstanceGroups"
    echo "step 9: ssh -i ./privatekey ubuntu@<ip_address>"
    echo "step 10: Quit"
    echo "step 11: Get Instance Types"
    echo ""

    read -p "Enter your choice: " choice

    case $choice in
      0)
        clear
        read -p "Please enter the path to your Kubeconfig file: " kubeconfig_path
        if [ ! -f "$kubeconfig_path" ]; then
          echo "Error: File not found."
        else
          kubeconfig_content=$(cat "$kubeconfig_path")
          if [ ${#kubeconfig_content} -le 100 ]; then
            echo "Error: Kubeconfig content is too short. Please make sure you provide the correct file."
          else
            kubeconfig_file="./kubeconfig.yaml"
            cp "$kubeconfig_path" "$kubeconfig_file"
            export KUBECONFIG="$kubeconfig_file"
            echo "Kubeconfig file has been copied and is now in use."
          fi
        fi
        ;;
      1)
        clear
        sprint "brew install kubelogin"
        brew install kubelogin
        ;;
      2)
        clear
        sprint "brew install kubectl"
        brew install kubectl
        ;;
      3)
        clear
        sprint "ssh-keygen -t rsa -b 4096 -f ./id_rsa_oe -q -N"
        ssh-keygen -t rsa -b 4096 -f ./id_rsa_oe -q -N ""
        ;;
      4)
        clear
        sprint "kubectl get instancegroups"
        kubectl get instancegroups
        ;;
      5)
        clear
        sprint "kubectl get instances -owide"
        kubectl get instances -owide
        ;;
      6)
        clear
        deleteInstanceGroups
        ;;
      7)
        clear
        read -p "Enter name: " name
        createImage $name
        ;;
      8)
        clear
        createInstanceGroups1
        ;;
      9)
        sshConnect;;
      10)
        echo "Exiting..."
        break
        ;;
      11) getInstanceTypes;;
      *)
        echo "Invalid option: $choice"
        ;;
    esac
  done
}

createInstanceGroup() {

  # Creating the YAML content
  yaml_content=$(cat <<EOF
metadata:
  name: $1
spec:
  image: $2
  instanceType: $3
  bootDiskSize: 120G
  networkInterfaces:
    - vpc: $5
  replicas: $4
  cloudInit:
    userData: |
      #cloud-config
      users:
        - name: ubuntu
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: users, admin
          home: /home/ubuntu
          shell: /bin/bash
          ssh_authorized_keys:
            - $6
      ssh_pwauth: False
      disable_root: false
      chpasswd:
        list: |
          ubuntu:ubuntu
        expire: False
      runcmd:
      - [ ls, -l, / ]
      - [ sudo, apt-get, update ]
      - [ sudo, apt-get, -y, install, apache2 ]
      - [ systemctl, enable, apache2 ]
      - [ systemctl, start, apache2 ]
      - echo 'This is the Ubuntu OS installed on OpenEdge' > /var/www/html/machine.html
      - iptables -F
      - iptables -P INPUT DROP
      - iptables -P FORWARD DROP
      - iptables -P OUTPUT ACCEPT
      - iptables -A INPUT -i lo -j ACCEPT
      - iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      - iptables -A INPUT -p tcp --dport 80 -j ACCEPT
      - iptables -A INPUT -p tcp --dport 443 -j ACCEPT
      - iptables -A INPUT -p tcp --dport 22 -j ACCEPT
      - iptables-save > /etc/iptables.rules
      write_files:
        - path: /etc/network/if-pre-up.d/iptables
          content: |
            #!/bin/sh
            /sbin/iptables-restore < /etc/iptables.rules
          permissions: '0755'
apiVersion: platform.qwilt.com/v1beta1
kind: InstanceGroup
EOF
)

  # Print the information message
  echo "Create InstanceGroup $1; App: $2; InstanceType = $3; Replicas: $4; VPC: $5"

  # Print the YAML content
  echo "$yaml_content"

  # Applying the YAML content with kubectl
  echo "$yaml_content" | kubectl apply -f -
}


createInstanceGroupOld() {

  # use the parameters in some command, here we are just passing them to echo
  echo "Create InstanceGroup $1 ; App: $2; InstanceType = $3; Replicas: $4; VPC: $5"
  echo ""

  kubectl apply -f - <<EOF
metadata:
  name: $1
spec:
  image: $2
  instanceType: $3
  bootDiskSize: 120G
  networkInterfaces:
    - vpc: $5
  replicas: $4
  cloudInit:
    userData: |
      #cloud-config
      users:
        - name: ubuntu
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: users, admin
          home: /home/ubuntu
          shell: /bin/bash
          ssh_authorized_keys:
            - $6
      ssh_pwauth: False
      disable_root: false
      chpasswd:
        list: |
          ubuntu:ubuntu
        expire: False
      runcmd:
      - [ ls, -l, / ]
      # install apache web-server
      - [ sudo, apt-get, update ]
      - [ sudo, apt-get, -y, install, apache2 ]
      - [ systemctl, enable, apache2 ]
      - [ systemctl, start, apache2 ]
      # add test HTML page
      - echo 'This is the Ubuntu OS installed on OpenEdge' > /var/www/html/machine.html
      # allow access to web ports only
      - iptables -F
      - iptables -P INPUT DROP
      - iptables -P FORWARD DROP
      - iptables -P OUTPUT ACCEPT
      - iptables -A INPUT -i lo -j ACCEPT
      - iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      - iptables -A INPUT -p tcp --dport 80 -j ACCEPT
      - iptables -A INPUT -p tcp --dport 443 -j ACCEPT
      - iptables -A INPUT -p tcp --dport 22 -j ACCEPT
      # allow SSH access only from the management subnet
      #- iptables -A INPUT -p tcp -s 80.179.204.0/24 --dport 22 -j ACCEPT
      - iptables-save > /etc/iptables.rules
      write_files:
        - path: /etc/network/if-pre-up.d/iptables
          content: |
            #!/bin/sh
            /sbin/iptables-restore < /etc/iptables.rules
          permissions: '0755'
apiVersion: platform.qwilt.com/v1beta1
kind: InstanceGroup
EOF
}

deleteInstanceGroups1() {
  sprint "Delete old InstanceGroups:"
  echo ""
  echo "kubectl delete instancegroup rons-ig1"
  echo "kubectl delete instancegroup rons-ig2"
  echo "kubectl delete instancegroup rons-ig3"
  echo "kubectl delete instancegroup rons-ig4"
  kubectl delete instancegroup rons-ig1
  kubectl delete instancegroup rons-ig2
  kubectl delete instancegroup rons-ig3
  kubectl delete instancegroup rons-ig4
}

createImage() {
  sprint "Create ComputeImage $1"

  command="
metadata:
  name: $1
spec:
  location: us
apiVersion: platform.qwilt.com/v1beta1
kind: ComputeImage
"
  runKubectl "$command"
}

createInstanceGroups() {
  sprint "Create InstanceGroups"

  public_key=$(cat ./id_rsa_oe.pub)
  echo "./create_instancegroup.sh rons-ig1 my-app-image-v1.2 qb500.large $public_key"
  createInstanceGroup rons-ig1 my-app-image-v1.2 qb500.large "$public_key"
  echo ""
}


deleteInstanceGroups() {
  sprint "Delete InstanceGroups:"
  echo "Fetching instance groups..."
  instancegroups=$(kubectl get instancegroups)
  echo "$instancegroups"
  echo -e "\nPlease select the line number of the instance group to delete (or 'q' to quit):"

  IFS=$'\n' # Change Internal Field Separator to handle each line
  select_options=($instancegroups)
  for (( i = 1; i < ${#select_options[@]}; i++ )); do
    echo "$i: ${select_options[$i]}"
  done

  read -p "Enter your choice: " choice

  if [ "$choice" = "q" ]; then
    return
  fi

  instancegroup_to_delete=$(echo "${select_options[$choice]}")
  instancegroup_name=$(echo "$instancegroup_to_delete" | awk '{print $1}') # Assuming the name is in the first column

  if [ -z "$instancegroup_name" ]; then
    echo "Invalid line number: $choice"
  else
    echo "Deleting instance group: $instancegroup_name"
    kubectl delete instancegroup "$instancegroup_name"
  fi
}

getInstanceTypes() {
  echo "Fetching instance types..."
  kubectl get instancetypes
}

createInstanceGroups1() {
 sprint "Create InstanceGroup"

  # Prompt for instance group name or generate one
  read -p "Enter instance group name (default is ig-$(date +"%m%d%H%M%S")): " instance_group_name
  if [ -z "$instance_group_name" ]; then
    instance_group_name="ig-$(date +"%m%d%H%M%S")"
  fi

  # Get available instance types and prompt the user to select one
  echo "Fetching instance types..."
  available_instance_types=$(kubectl get instancetypes)
  IFS=$'\n'
  select_options=($available_instance_types)
  for (( i = 1; i < ${#select_options[@]}; i++ )); do
    echo "$i: ${select_options[$i]}"
  done
  read -p "Select instance type by line number (default is qb500.medium): " instance_type_choice
  if [ -z "$instance_type_choice" ]; then
    instance_type="qb500.medium"
  else
    instance_type=$(echo "${select_options[$instance_type_choice]}" | awk '{print $1}') # Assuming the instance type is in the first column
  fi


  # Get available compute images and prompt the user to select one
  echo "Fetching compute images..."
  available_compute_images=$(kubectl get computeimages)
  if [ -z "$available_compute_images" ]; then
    echo "No compute images found. Please create one and try again."
    return
  fi
  IFS=$'\n'
  select_options=($available_compute_images)
  for (( i = 1; i < ${#select_options[@]}; i++ )); do
    echo "$i: ${select_options[$i]}"
  done
  read -p "Select compute image by line number (default is 1): " compute_image_choice
  if [ -z "$compute_image_choice" ]; then
    compute_image_choice=1
  fi
  compute_image=$(echo "${select_options[$compute_image_choice]}" | awk '{print $1}') # Assuming the compute image is in the first column

  # Prompt for replicas
  read -p "Enter number of replicas (default is 1): " replicas
  if [ -z "$replicas" ]; then
    replicas=1
  fi

  # Prompt for vpc
  read -p "Enter VPC (default is 'default'): " vpc
  if [ -z "$vpc" ]; then
    vpc="default"
  fi

  # Public key
  public_key=$(cat ./id_rsa_oe.pub)

  # Create the instance group
  echo "./create_instancegroup.sh $instance_group_name $compute_image $instance_type $public_key $replicas $vpc"
  createInstanceGroup "$instance_group_name" "$compute_image" "$instance_type" "$replicas" "$vpc" "$public_key"
  echo ""
}

sshConnect() {
  echo "Fetching available instances..."
  available_instances=$(kubectl get instances -owide)
  IFS=$'\n'
  select_options=($(echo "$available_instances" | awk 'NR>1'))
  for (( i = 1; i <= ${#select_options[@]}; i++ )); do
    echo "$i: ${select_options[$i - 1]}"
  done
  read -p "Select instance by line number (default is 1): " instance_choice
  if [ -z "$instance_choice" ] || [ "$instance_choice" -eq 1 ]; then
    instance_choice=1
  fi
  ip_address=$(echo "${select_options[$instance_choice - 1]}" | awk '{print $5}') # Replace COLUMN_NUMBER with the correct column number for the IP address
  clear
  echo "ssh -i ./id_rsa_oe ubuntu@$ip_address"
  ssh -i ./id_rsa_oe ubuntu@$ip_address
}




clear
echo "1Welcome to OpenEdge InstanceGroup Demo!"
echo
export KUBECONFIG=./kubeconfig.yaml
instancesMenu
