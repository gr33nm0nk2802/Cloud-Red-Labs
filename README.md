# Cloud-Red-Labs
<p align="center">
  <img src="./artifacts/images/Logo.png" alt="logo" width="800" />
</p>

<p align="center">
  <img src="https://img.shields.io/github/stars/gr33nm0nk2802/Cloud-Red-Labs?style=flat" alt="Stars" />
  <img src="https://img.shields.io/github/forks/gr33nm0nk2802/Cloud-Red-Labs?style=flat" alt="Forks" />
  <img src="https://img.shields.io/github/issues/gr33nm0nk2802/Cloud-Red-Labs?style=flat" alt="Issues" />
  <img src="https://img.shields.io/github/last-commit/gr33nm0nk2802/Cloud-Red-Labs" alt="Last Commit" />
  <a href="https://github.com/gr33nm0nk2802/Cloud-Red-Labs"><img src="https://img.shields.io/badge/Category-Cloud%20Red%20Team-green.svg" alt="Category" /></a>
  <a href="https://github.com/gr33nm0nk2802/Cloud-Red-Labs/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" /></a>
  <a href="https://github.com/gr33nm0nk2802/Cloud-Red-Labs/pulls"><img src="https://img.shields.io/badge/PRs-welcome-success.svg" alt="Pull Requests" /></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/Python-3.8%2B-green.svg" alt="Python" /></a>
</p>

<p align="center">
  <!-- Infra tooling badges -->
  <a href="https://www.terraform.io/"><img src="https://img.shields.io/badge/Terraform-0.13%2B-5f3c88?style=flat&logo=terraform&logoColor=white" alt="Terraform" /></a>
  <a href="https://docs.aws.amazon.com/cli/"><img src="https://img.shields.io/badge/AWS_CLI-2.x-232F3E?style=flat&logo=amazonaws&logoColor=white" alt="AWS CLI" /></a>
  <a href="https://learn.microsoft.com/cli/azure/"><img src="https://img.shields.io/badge/Azure_CLI-2.x-0078D4?style=flat&logo=microsoft-azure&logoColor=white" alt="Azure CLI" /></a>
</p>

<p align="center">
  Built with ❤️ by <a href="https://linkedin.com/in/gr33nm0nk2802" target="_blank" rel="noopener noreferrer">@gr33nm0nk2802</a><br><br>
  <strong>Cloud-Red-Labs</strong> — intentionally vulnerable cloud Red Team lab environment for learning and practicing common AWS &amp; Azure security flaws, exploitation techniques, and cloud-based Red Team operations. 
</p>

> Future editions will support other cloud providers.

# Red Teaming Lifecycle

- Recon                     
- Initial Access            
- Persistence               
- Privilege Escalation      
- Lateral Movement          
- Exfiltration            

<p align="center">
  <img src="./artifacts/images/RT-Lifecycle.png" alt="logo" width="800" />
</p>


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

## How to Deploy the lab?

1. Clone the repo and navigate to the specific repository

```bash
git clone git@github.com:gr33nm0nk2802/Cloud-Red-Labs.git
cd cloud-red-lab
```

2. If you make changes to the application code under `artifacts/src`. Run the following.

> Note: Please don't use the default credentials. Change the password in azure/app.py and the password and secret in aws-app/app.py.

```bash
cd artifacts
chmod +x build.sh
./build.sh
```

3. To deploy Azure challenge. 

Login to the `azcli` from your console.

```bash
cd azure/

az login --tenant $TENANT_ID --use-device-code --scope https://management.core.windows.net/.default
# az login --tenant $TENANT_ID --use-device-code --scope https://graph.microsoft.com/.default

terraform init
terraform apply --auto-approve
```

4. To deploy the AWS challenge.

Login to `awscli`

```bash
cd aws/

aws configure

terraform init
terraform apply --auto-approve
```

5. To destroy the AWS or Azure lab, navigate to the respective directory and run.

```bash
terraform destroy --auto-approve
```

## Azure Lab
### Attack Path

<p align="center">
  <img src="./artifacts/images/azure/Azure-Attack-Path.png" alt="Azure Attack Path" width="800" />
</p>

### Scenarios

- **A-A1 — SSTI → Managed Identity token** *(Easy → Medium)*  
  **Goal:** Abuse SSTI to obtain managed identity token (lab **Flag 1**).  
  **Hint:** Inspect app responses and identity metadata.  
  **Mitigation:** Fix SSTI, limit managed identity permissions.

- **A-A2 — Managed identity → KeyVault → SAS** *(Medium)*  
  **Goal:** Read KeyVault (Flag 2) and use SAS to fetch blob (Flag 3).  
  **Hint:** Check vault policies and secret contents for storage URLs.  
  **Mitigation:** Restrict vault access, avoid broad SAS tokens, enable auditing.

- **A-A3 — Blob → creds → lateral exec** *(Medium → Hard)*  
  **Goal:** Harvest creds from blob, run limited commands as `BkpUser`, capture **Flag 4**.  
  **Hint:** Correlate blob contents to user/host access.  
  **Mitigation:** Enforce credential hygiene, conditional access, JIT access, logging.

## Solution 

[Available here](./azure/Solution.md)

---

## AWS Lab
### Attack Path

<p align="center">
  <img src="./artifacts/images/aws/AWS-Attack-Path.png" alt="Azure Attack Path" width="800" />
</p>

### Scenarios

- **W-B1 — Lambda exec → Temp creds** *(Easy → Medium)*  
  **Goal:** Capture **Flag 1** from the vulnerable Lambda runtime.  
  **Hint:** Inspect runtime metadata / role.  
  **Mitigation:** Narrow Lambda IAM role & remove secrets from code.

- **W-B2 — Assume role → S3 read** *(Medium)*  
  **Goal:** Use temp creds to assume S3-reader and fetch **Flag 2**.  
  **Hint:** Check trust policies & bucket policy scope.  
  **Mitigation:** Tighten trust relationships; deny public bucket access.

- **W-B3 — Long-term secret → Secret store** *(Medium → Hard)*  
  **Goal:** Locate long-term key, read corp secrets, get **Flag 3**.  
  **Hint:** Find stored credentials and their access scope.  
  **Mitigation:** Remove long-lived keys; enforce rotation and access controls.

- **W-B4 — Secrets → RDS access** *(Hard)*  
  **Goal:** Use retrieved secrets to access RDS and retrieve **Flag 4**.  
  **Hint:** Map which secret unlocks which resource.  
  **Mitigation:** Network segmentation, IAM+network DB restrictions, audit DB auth.

## Solution 

[Available here](./aws/Solution.md)

# Presentation

![DC-Bahrain-25](./slides/Breaking-Boundaries-Multi-Cloud-Red-Teaming.pdf)
[DC-Bahrain-25](./slides/Breaking-Boundaries-Multi-Cloud-Red-Teaming.pdf)
---





