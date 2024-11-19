####################################################################################
##  File:  Install-AzureCosmosDbEmulator.ps1
##  Desc:  Install Azure CosmosDb Emulator
####################################################################################

Install-Binary -Type MSI `
    -Url "https://aka.ms/cosmosdb-emulator" `
    -ExpectedSHA256Sum "9870895021BDD6512E815666279A7D57C0BE9BA5767A3340BACAF61377DC0065"

Invoke-PesterTests -TestFile "Tools" -TestName "Azure Cosmos DB Emulator"
