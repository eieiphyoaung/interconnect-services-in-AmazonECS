
## counting-service binary (Linux ARM64 for Docker/ECS)
curl -LO https://github.com/hashicorp/demo-consul-101/releases/download/v0.0.5/counting-service_linux_arm64.zip
unzip counting-service_linux_arm64.zip
rm -rf counting-service_linux_arm64.zip
mv counting-service_linux_arm64 counting-service
chmod +x counting-service

## dashboard-service binary (Linux ARM64 for Docker/ECS)
curl -LO https://github.com/hashicorp/demo-consul-101/releases/download/v0.0.5/dashboard-service_linux_arm64.zip
unzip dashboard-service_linux_arm64.zip
rm -rf dashboard-service_linux_arm64.zip
mv dashboard-service_linux_arm64 dashboard-service
chmod +x dashboard-service

## For local macOS testing (Darwin ARM64)
# curl -LO https://github.com/hashicorp/demo-consul-101/releases/download/v0.0.5/counting-service_darwin_arm64.zip
# unzip counting-service_darwin_arm64.zip && chmod +x counting-service_darwin_arm64
# curl -LO https://github.com/hashicorp/demo-consul-101/releases/download/v0.0.5/dashboard-service_darwin_arm64.zip
# unzip dashboard-service_darwin_arm64.zip && chmod +x dashboard-service_darwin_arm64

## running dashboard-service
export PORT=9002
export COUNTING_SERVICE_URL="http://localhost:9003"
./dashboard-service

### another way to run as a single line
PORT=9002 COUNTING_SERVICE_URL="http://localhost:9003" ./dashboard-service


## running counting service
export PORT=9003
./counting-service


## counting, dashboard public image

public.ecr.aws/j6k7m6l0/counting-service
public.ecr.aws/j6k7m6l0/dashboard-service


## Create Public Registry in AWS ECR

aws ecr-public create-repository \
  --repository-name counting-service \
  --region us-east-1 \
  --profile master-programmatic-admin


aws ecr-public create-repository \
  --repository-name dashboard-service \
  --region us-east-1 \
  --profile master-programmatic-admin

## AWS Login
aws ecr-public get-login-password --region us-east-1 --profile master-programmatic-admin \
  | docker login --username AWS --password-stdin public.ecr.aws


## Check the repository list
aws ecr-public describe-repositories --region us-east-1  --profile master-programmatic-admin

## Tag the image
docker tag ei2000/counting:latest \
public.ecr.aws/f1x9o8v2/counting-service:latest

docker tag ei2000/dashboard:latest \
public.ecr.aws/f1x9o8v2/dashboard-service:latest

## Push the image to Public Repository
docker push public.ecr.aws/f1x9o8v2/counting-service:latest
docker push public.ecr.aws/f1x9o8v2/dashboard-service:latest


## Verify TLS enabled

### From Dashboard to Counting

$ aws ecs execute-command --cluster demo-cluster \
    --task arn:aws:ecs:ap-southeast-1:820242905231:task/demo-cluster/9c31af6a251f43d29501669e143ba054  \
    --profile master-programmatic-admin --region ap-southeast-1 \
    --container dashboard \
    --interactive \
    --command "/bin/sh"

$ apk update && apk add curl
$ curl -iv http://counting-dns:9003

$apk add openssl

$ openssl s_client -connect 172.31.20.103:9003 < /dev/null 2> /dev/null | openssl x509 -noout -text
$ openssl s_client -connect 172.31.20.103:9003 -showcerts < /dev/null



### From Counting to Dashboard

$ aws ecs execute-command --cluster demo-cluster \
    --task arn:aws:ecs:ap-southeast-1:820242905231:task/demo-cluster/31466e0e9a1440b2b3f58a02e379ad10  \
    --profile master-programmatic-admin --region ap-southeast-1 \
    --container counting \
    --interactive \
    --command "/bin/sh"


$ openssl s_client -connect 172.31.30.91:9002 < /dev/null 2> /dev/null | openssl x509 -noout -text

$ openssl s_client -connect 172.31.30.91:9002 -showcerts < /dev/null


