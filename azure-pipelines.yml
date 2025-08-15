# subscription-api / azure-pipelines.yml
trigger: none
pr: none

pool:
  name: Default

variables:
  - name: System.Debug
    value: 'true'

stages:
# =========================================================
# Stage0: Subscription (Create via AzAPI)
# =========================================================
- stage: stage0_subscription
  displayName: "Stage0 - Create Subscription (AzAPI)"
  jobs:
  - job: run_tf
    displayName: "Terraform apply (subscription)"
    steps:
    - powershell: |
        Write-Host "Agent Name  : $env:AGENT_NAME"
        Write-Host "Agent OS    : $env:AGENT_OS"
        Write-Host "Agent Ver   : $env:AGENT_VERSION"
      displayName: "Show Agent Info"

    # ← AzureCLI@2 で Service connection によりログイン
    - task: AzureCLI@2
      name: tf
      displayName: 'Terraform init/plan/apply (Stage0)'
      inputs:
        azureSubscription: 'snp-pipeline-api'        # ← 作成済みサービス接続名
        scriptType: ps
        scriptLocation: inlineScript
        inlineScript: |
          $ErrorActionPreference = 'Stop'
          $stageDir = "$(Build.SourcesDirectory)/terraform/stage0-subscription"
          $tfvars   = "$(Build.SourcesDirectory)/terraform/stage0-subscription/terraform.tfvars"

          if (-not (Test-Path $tfvars)) {
            Write-Host "Repo root:" $(Build.SourcesDirectory)
            Get-ChildItem -Recurse "$(Build.SourcesDirectory)/terraform" | Select-Object FullName
            Write-Error "terraform.tfvars が見つかりません: $tfvars"
          }

          Push-Location $stageDir

          Write-Host "== terraform init =="
          terraform init

          Write-Host "== terraform plan =="
          terraform plan -var-file="$tfvars" -out plan.out

          Write-Host "== terraform apply =="
          terraform apply -auto-approve plan.out

          # 出力を次ステージへ渡す
          $subId = ""
          try { $subId = terraform output -raw subscription_id } catch {}
          Write-Host "subscriptionId=$subId"
          Write-Host "##vso[task.setvariable variable=subscriptionId;isOutput=true]$subId"

          Pop-Location

# =========================================================
# Stage1〜4: プレースホルダー
# =========================================================

# Stage1: Resource Group
- stage: stage1_rg
  displayName: "Stage1 - Resource Group"
  dependsOn: stage0_subscription
  variables:
    subscriptionId: $[ stageDependencies.stage0_subscription.run_tf.outputs['tf.subscriptionId'] ]
  jobs:
  - job: placeholder_rg
    steps:
    - task: AzureCLI@2
      displayName: "[RG] placeholder"
      inputs:
        azureSubscription: 'snp-pipeline-api'
        scriptType: bash
        scriptLocation: inlineScript
        inlineScript: |
          set -e
          echo "[RG] placeholder"
          echo "SubscriptionId from Stage0: $(subscriptionId)"
          if [ -n "$(subscriptionId)" ]; then
            az account set --subscription "$(subscriptionId)"
            az account show --query "{id:id,name:name}" -o tsv || true
          fi

# Stage2: VNet
- stage: stage2_vnet
  displayName: "Stage2 - VNet"
  dependsOn: stage1_rg
  jobs:
  - job: placeholder_vnet
    steps:
    - bash: echo "[VNET] placeholder"

# Stage3: Subnet
- stage: stage3_subnet
  displayName: "Stage3 - Subnet"
  dependsOn: stage2_vnet
  jobs:
  - job: placeholder_subnet
    steps:
    - bash: echo "[SUBNET] placeholder"

# Stage4a: Peering Spoke->Hub
- stage: stage4a_peering_s2h
  displayName: "Stage4a - Peering Spoke->Hub"
  dependsOn: stage3_subnet
  jobs:
  - job: placeholder_peering_s2h
    steps:
    - bash: echo "[PEERING S->H] placeholder"

# Stage4b: Peering Hub->Spoke
- stage: stage4b_peering_h2s
  displayName: "Stage4b - Peering Hub->Spoke"
  dependsOn: stage4a_peering_s2h
  jobs:
  - job: placeholder_peering_h2s
    steps:
    - bash: echo "[PEERING H->S] placeholder"
