pipeline{
    agent {label 'agent-one'}
    stages{
        stage("Code"){
            steps{
                echo "This is cloning the code"
                git credentialsId: 'github-pat', url: 'https://github.com/Fahad-Md-Kamal/investor-pro.git', branch:"main"
                echo "Code cloned successfully"
                
                echo "Copy .env"
                sh "mv .env.example .env"
                echo ".env copied successfully"
            }
        }
        // stage("Build"){
        //     steps{
        //         echo "This is building the code"
        //         sh "docker build -t investor-pro:${env.BUILD_NUMBER} -t investor-pro:latest ."
        //     }
        // }
        stage("Test"){
            steps{
                echo "This is testing the code"
            }
        }
        stage("Deploy"){
            steps{
                echo "This is deploying the code"
                echo "Now building Backend docker image"

                sh "make start"

                // sh """
                //     docker stop investor-pro || true
                //     docker rm investor-pro || true
                //     docker run -d --name investor-pro --restart unless-stopped \\
                //         -p 8000:8000 \\
                //         investor-pro:${env.BUILD_NUMBER}
                // """
                
                echo "Deployed everything successfully"
            }
        }
        stage("Setup-Data"){
            steps{
                echo "Setup data"

                sh """
                    mkdir -p data/raw
                    unzip -o stock-data.zip -d ./data/raw/amarstock
                """
                
                echo "Ingestable data unzipped successfully"
            }
        }
        stage("Ingest All Data"){
            steps{
                echo "Ingest all data now"

                sh "docker compose exec -T app python -m src.ingest_data --source all"
                
                echo "Ingested all data successfully"
            }
        }
    }
}