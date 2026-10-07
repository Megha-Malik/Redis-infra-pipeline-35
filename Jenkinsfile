pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Select "apply" to create & configure infrastructure or "destroy" to clean up.'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Megha-Malik/Redis-infra-pipeline-35.git'
            }
        }

        stage('Terraform Action') {
            steps {
                dir('terraform') {
                    withCredentials([aws(credentialsId: 'aws-credentials', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                            terraform init

                            if [ "${ACTION}" = "apply" ]; then
                                echo "=== Provisioning Infrastructure ==="
                                terraform apply -auto-approve -var="key_name=Redis-key"
                            elif [ "${ACTION}" = "destroy" ]; then
                                echo "=== Destroying Infrastructure ==="
                                terraform destroy -auto-approve -var="key_name=Redis-key"
                            fi
                        '''
                    }
                }
            }
        }

        stage('Configure Redis via Ansible Dynamic Inventory') {
            when {
                expression { return params.ACTION == 'apply' }
            }
            steps {
                dir('ansible') {
                    withCredentials([
                        aws(credentialsId: 'aws-credentials', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'),
                        sshUserPrivateKey(credentialsId: 'ssh-private-key', keyFileVariable: 'SSH_KEY_PATH')
                    ]) {
                        sh '''
                            echo "=== Waiting 30s for instances to initialize SSH ==="
                            sleep 30

                            BASTION_IP=$(cd ../terraform && terraform output -raw bastion_public_ip)
                            echo "Bastion Public IP is: ${BASTION_IP}"

                            # Run Ansible Playbook using Bastion as SSH Jump Host
                            # Note: '--user ec2-user' removed to allow aws_ec2.yml dynamic user selection (ubuntu / ec2-user)
                            ansible-playbook -i aws_ec2.yml setup-redis.yml \
                              --private-key ${SSH_KEY_PATH} \
                              --ssh-common-args="-o ProxyCommand='ssh -W %h:%p -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ec2-user@${BASTION_IP}' -o StrictHostKeyChecking=no"
                        '''
                    }
                }
            }
        }
    }
}