pipeline{
    agent {label 'agent-one'}
    stages{
        stage("Code"){
            steps{
                echo "This is cloning the code"
                git credentialsId: 'github-pat', url: 'https://github.com/Fahad-Md-Kamal/investor-pro.git', branch:"holding/ui"
                echo "Code cloned successfully"
            }
        }
        stage("Build"){
            steps{
                echo "This is building the code"
                sh "docker build -t investor-pro:${env.BUILD_NUMBER} -t investor-pro:latest ."
            }
        }
        stage("Test"){
            steps{
                echo "This is testing the code"
            }
        }
        stage("Deploy"){
            steps{
                echo "This is deploying the code"
            }
        }
    }
}