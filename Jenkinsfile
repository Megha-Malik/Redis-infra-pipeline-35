```groovy
pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Select apply to create infrastructure or destroy it.'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Megha-Malik/Redis-infra-pipeline-35.git'
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    withCredentials([
                        aws(
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -e
                            echo "=== Terraform Init Started ==="
                            terraform init -input=false
                            echo "=== Terraform Init Completed ==="
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        aws(
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -e

                            echo "=== Terraform Plan Started ==="

                            terraform plan \
                              -var="key_name=Redis-key" \
                              -out=tfplan

                            echo "=== Terraform Plan Command Finished ==="

                            if [ ! -s tfplan ]; then
                                echo "ERROR: tfplan file is missing or empty"
                                exit 1
                            fi

                            ls -lh tfplan
                            echo "=== Terraform Plan Completed Successfully ==="
                        '''
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        aws(
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -e

                            echo "=== Terraform Apply Started ==="

                            if [ ! -s tfplan ]; then
                                echo "ERROR: tfplan file not found"
                                exit 1
                            fi

                            terraform apply -auto-approve tfplan

                            echo "=== Terraform Apply Completed Successfully ==="
                        '''
                    }
                }
            }
        }

        stage('Verify Terraform State in S3') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        aws(
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -e

                            echo "=== Verifying Terraform State in S3 ==="

                            terraform state list

                            echo "=== Terraform State Verification Completed ==="
                        '''
                    }
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        aws(
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -e

                            echo "=== Terraform Destroy Started ==="

                            terraform destroy \
                              -auto-approve \
                              -var="key_name=Redis-key"

                            echo "=== Terraform Destroy Completed ==="
                        '''
                    }
                }
            }
        }

        stage('Configure Redis via Ansible Dynamic Inventory') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('ansible') {
                    withCredentials([
                        aws(
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ),
                        sshUserPrivateKey(
                            credentialsId: 'ssh-private-key',
                            keyFileVariable: 'SSH_KEY_PATH'
                        )
                    ]) {
                        sh '''
                            set -e

                            echo "=== Waiting for SSH ==="
                            sleep 30

                            BASTION_IP=$(cd ../terraform &&
                                terraform output -raw bastion_public_ip)

                            echo "Bastion Public IP: ${BASTION_IP}"

                            ansible-playbook \
                              -i aws_ec2.yml \
                              setup-redis.yml \
                              -u ec2-user \
                              --private-key "${SSH_KEY_PATH}" \
                              --ssh-common-args="-o ProxyCommand='ssh -W %h:%p -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ec2-user@${BASTION_IP}' -o StrictHostKeyChecking=no"

                            echo "=== Redis Configuration Completed ==="
                        '''
                    }
                }
            }
        }
    }
}
```


