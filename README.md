# azure-switchbot-monitor

## feature

- Get information on all thermo-hygrometers connected to the SwitchBot Hub using SwitchBot API 1.1
- Functions application hosted on Azure periodically acquires sensor information and stores it in Log Analytics
- Using the latest Data Collection Endpoint and Data Collection Rule features in Azure monitor
- The Function application is implemented in Python 3 and uses the Azure SDK for Python

![img](/docs/infra.png)

## quick start

### Azure infrastructure

To deploy Azure infrastructure, use ". /template" directory to deploy Azure infrastructure.

Edit the contents of the file and set the values of SWITCHBOT_TOKEN and SWITCHBOT_SECRET.

Each value can be retrieved from the SwitchBot application on your smartphone.

For more information, please refer to the following website

[https://github.com/OpenWonderLabs/SwitchBotAPI#getting-started](https://github.com/OpenWonderLabs/SwitchBotAPI#getting-started)

Azure CLI is used in the script.

Log in to Azure with the "az login" command.

The Azure account must have "owner" privileges granted to the subscription.

```sh
az login --tenant (your tenant name or id)
cd template
./deploy.sh
```

As shown below, various resources are created in the resource group specified in deploy.sh.

![img](/docs/01.png)

### Function Application

It is easy to deploy from a client PC using Visual Studio Code's Azure extension.

You are probably more familiar with the detailed procedure.

If you have "\_\_init\_\_.py" and "function.json" under /SwitchbotMonitor, it will (probably) work.

For local debugging in Visual Studio Code, create an Azure AD application (service principal) in advance and add it as "Monitoring Metrics Publisher" in the IAM of the Data Collection Rule. This will work.

The following is an example of "local.settings.json".

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "SWITCHBOT_TOKEN": "***",
    "SWITCHBOT_SECRET": "***",
    "AZURE_TENANT_ID": "***",
    "AZURE_CLIENT_ID": "***",
    "AZURE_CLIENT_SECRET": "***",
    "AZURE_MONITOR_ENDPOINT": "https://***.japaneast-1.ingest.monitor.azure.com",
    "AZURE_MONITOR_IMMUTABLEID": "dcr-***",
    "AZURE_MONITOR_STREAMNAME": "Custom-switchbot_CL"
  }
}
```

## Execution example

Here is an example of a KQL that will be listed in Log Analytics.

```text
switchbot_CL 
| project TimeGenerated, deviceName, toreal(body.temperature), toreal(body.humidity)
| order by TimeGenerated
| render table  
```

![img](/docs/02.png)

It's also easy to graph.

![img](/docs/03.png)
