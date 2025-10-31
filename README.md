# Cloud-Red-Labs
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;![logo](./artifacts/images/Logo.png)
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
![Stars](https://img.shields.io/github/stars/gr33nm0nk2802/Cloud-Red-Labs?style=flat)
![Forks](https://img.shields.io/github/forks/gr33nm0nk2802/Cloud-Red-Labs?style=flat)
![Issues](https://img.shields.io/github/issues/gr33nm0nk2802/Cloud-Red-Labs?style=flat)
![Last Commit](https://img.shields.io/github/last-commit/gr33nm0nk2802/Cloud-Red-Labs)
[![Category](https://img.shields.io/badge/Category-Cloud%20Red%20Team-green.svg)](https://github.com/gr33nm0nk2802/Cloud-Red-Labs)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/gr33nm0nk2802/Cloud-Red-Labs/blob/main/LICENSE)
[![Pull Requests](https://img.shields.io/badge/PRs-welcome-success.svg)](https://github.com/gr33nm0nk2802/Cloud-Red-Labs/pulls)
[![Python](https://img.shields.io/badge/Python-3.8%2B-green.svg)](https://www.python.org/)
<br>

Intentionally designed vulnerable cloud lab environment for learning and practicing common cloud security flaws, exploitation techniques, and Red Team operations across Azure and AWS platforms.

Author: [@gr33nm0nk2802](https://linkedin.com/in/gr33nm0nk2802)


> Future editions will support other cloud providers.

# Red Teaming Lifecycle

- Recon                     
- Initial Access            
- Privilege Escalation      
- Lateral Movement          
- Persistence               
- Exfiltration              

# Pre-Requisites 

## To deploy the lab
1. AWS Account with Administrative Access (To deploy the AWS labs)
2. Azure Account with Administrative Access (To deploy the Azure labs)
3. Terraform must be installed.
4. mysql must be installed for deploying the AWS challenge.

> Note: Run the commands from a linux terminal since, it has been tested. For windows users having a quick WSL access helps.

## To solve the challenge lab
1. PowerShell/Bash
2. Curl
4. azcli
5. awscli
6. mysql
7. python

> Note: Attacks are possible from Windows/MAC/Linux as long as you have the above installed.

# Deployment
## Build the Application

1. If you make changes to the application code under `artifacts/src`. Run the following.

```bash
cd artifacts
chmod +x build.sh
./build.sh
```

## How to Deploy the lab?

1. Clone the repo and navigate to the specific repository

```bash
git clone [RepoUrl]
cd cloud-red-lab
```

2. To deploy Azure challenge. 

Login to the `azcli` from your console.

```bash
cd azure/

az login --tenant $TENANT_ID --use-device-code --scope https://management.core.windows.net/.default
# az login --tenant $TENANT_ID --use-device-code --scope https://graph.microsoft.com/.default

terraform init
terraform apply --auto-approve
```

3. To deploy the AWS challenge.

Login to `awscli`

```bash
cd aws/

aws configure

terraform init
terraform apply --auto-approve
```

4. To destroy the AWS or Azure lab, navigate to the respective directory and run.

```bash
terraform destroy --auto-approve
```

## Azure Lab

![](./artifacts/images/azure/Azure-Attack-Path.png)

## Scenarios

## Solution 

[Available here](./azure/Solution.md)

## AWS Lab
![](./artifacts/images/aws/AWS-Attack-Path.png)

## Scenarios

## Solution 

[Available here](./aws/Solution.md)

