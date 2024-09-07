## Terraform Solution for Web App Deployment
This Terraform configuration sets up a simple web app on Amazon EC2, load-balanced using an Elastic Load Balancer (ELB), and connected to a private Amazon RDS instance. Shared storage between the instances is achieved using Amazon EFS. Additionally, a CloudWatch alarm is added to monitor and trigger an alert when the total number of requests exceeds a specified threshold.

## Prerequisites
- AWS account with appropriate credentials and permissions.
- Terraform installed on your local machine.
## Configuration
Create a file named secrets.tfvars to store sensitive data, such as database credentials and IP address. Example content:
```sh
db_username = "your_db_username"
db_password = "your_db_password"
my_ip       = "your_public_ip_address"
```
Update the variables in variables.tf to match your requirements, including the AWS region, subnet CIDR blocks, etc.

## Deployment
Initialize Terraform:

```sh
terraform init
```
Review the changes that Terraform will apply:

```sh
terraform plan -var-file=secrets.tfvars
```
## Deploy the infrastructure:

```sh
terraform apply -var-file=secrets.tfvars
```
Retrieve the DNS name of the Elastic Load Balancer (ELB) from the Terraform output. Use this DNS name to access the web app.

## Cleanup
To destroy the infrastructure:

```sh
terraform destroy -var-file=secrets.tfvars
```
Confirm destruction by typing yes when prompted.

## Notes
- This configuration is tailored to the task's requirements. Ensure proper security measures are taken before deploying in a production environment.

- Sensitive data should be kept secure and not committed to version control.

For more details on Terraform, refer to the official Terraform documentation.