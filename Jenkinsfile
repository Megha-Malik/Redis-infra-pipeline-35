pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose apply to create infrastructure or destroy to remove it.'
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

        stage('Validate Tools') {
            steps {
                sh '''
                    echo "=== Checking Required Tools ==="
                    git --version
                    terraform -version
                    ansible --version
                    aws --version
                '''
            }
        }

        stage('Terraform Format & Validate') {
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
                            echo "=== Initializing Terraform ==="
                            terraform init -input=false

                            echo "=== Validating Terraform Configuration ==="
                            terraform validate

                            echo "=== Terraform Format Check (Informational) ==="
                            terraform fmt -check -recursive || {
                                echo "Formatting differences detected."
                                echo "Continuing without modifying Terraform files."
                            }
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
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
                            if [ "$ACTION" = "apply" ]; then
                                terraform plan -input=false \
                                  -var="key_name=Redis-key" \
                                  -out=tfplan
                            elif [ "$ACTION" = "destroy" ]; then
                                terraform plan -destroy -input=false \
                                  -var="key_name=Redis-key" \
                                  -out=tfplan
                            fi
                        '''
                    }
                }
            }
        }

        stage('Terraform Action') {
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
                            echo "=== Executing Terraform $ACTION ==="
                            terraform apply -input=false -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Verify Infrastructure') {
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
                            echo "=== Infrastructure Outputs ==="
                            terraform output
                            echo "=== Bastion Public IP ==="
                            terraform output -raw bastion_public_ip
                        '''
                    }
                }
            }
        }

        stage('Configure Redis via Ansible') {
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
                            echo "=== Waiting for instances to initialize ==="
                            sleep 30

                            BASTION_IP=$(cd ../terraform &&
                                terraform output -raw bastion_public_ip)

                            echo "Bastion IP: ${BASTION_IP}"

                            ansible-playbook \
                              -i aws_ec2.yml \
                              setup-redis.yml \
                              -u ec2-user \
                              --private-key "$SSH_KEY_PATH" \
                              --ssh-common-args="-o ProxyCommand='ssh -W %h:%p -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP' -o StrictHostKeyChecking=no"
                        '''
                    }
                }
            }
        }

        stage('Redis Health Check') {
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
                            echo "=== Checking Redis Service ==="

                            BASTION_IP=$(cd ../terraform &&
                                terraform output -raw bastion_public_ip)

                            ansible -i aws_ec2.yml all \
                              -u ec2-user \
                              --private-key "$SSH_KEY_PATH" \
                              --ssh-common-args="-o ProxyCommand='ssh -W %h:%p -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP' -o StrictHostKeyChecking=no" \
                              -m shell \
                              -a "sudo systemctl is-active redis"
                        '''
                    }
                }
            }
        }

        stage('Verify Destroy') {
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
                            echo "=== Verifying Terraform Cleanup ==="
                            terraform state list
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully. ACTION=${params.ACTION}"
        }

        failure {
            echo "Pipeline failed. Check the Jenkins console output."
        }

        always {
            echo "Pipeline execution finished."
            cleanWs()
        }
    }
}
