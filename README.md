# cloud_computing_project
1. set up aws account on https://aws.amazon.com
2. download terraform from https://developer.hashicorp.com/terraform/install
3. in cmd, go to folder with main.tf and lambda_function.zip
4. run:\
"your_path_to_downloaded_terraform\terraform.exe" init\
"your_path_to_downloaded_terraform\terraform.exe" plan\
"your_path_to_downloaded_terraform\terraform.exe" apply\
enter 'yes' value when asked
5. check aws webpage if stuff that .tf code should do is done (Lambda->Functions, DynamoDB->Tables, API Gateway->APIs)
