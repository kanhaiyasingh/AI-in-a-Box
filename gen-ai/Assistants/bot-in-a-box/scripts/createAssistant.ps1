Write-Host "Loading azd .env file from current environment"
foreach ($line in (& azd env get-values)) {
    if ($line -match "([^=]+)=(.*)") {
        $key = $matches[1]
        $value = $matches[2] -replace '^"|"$'
	    [Environment]::SetEnvironmentVariable($key, $value)
    }
}

$AOAI_API_KEY=az cognitiveservices account keys list -n $env:AOAI_NAME -g $env:AZURE_RESOURCE_GROUP_NAME --query key1 -o tsv
$AOAI_ASSISTANT_NAME="assistant_in_a_box"
$ASSISTANT_ID=((curl "$env:AOAI_API_ENDPOINT/openai/assistants?api-version=2024-02-15-preview" -H "api-key: $AOAI_API_KEY" | ConvertFrom-Json).data | Where-Object name -eq $AOAI_ASSISTANT_NAME).id
if ( "$ASSISTANT_ID" == "null" )    
    {ASSISTANT_ID=""}
else
    {ASSISTANT_ID=/$ASSISTANT_ID}

echo "{
    `"name`":`"${AOAI_ASSISTANT_NAME}`",
    `"model`":`"gpt-4`",
    `"instructions`":`"`",
    `"tools`":[
        $(Get-ChildItem "./src/Tools" -Filter *.json | 
          Foreach-Object {
              $content = Get-Content $_.FullName
              echo $content","
          })
        {}
    ],
    `"file_ids`":[],
    `"metadata`":{}
  }" > tmp.json
curl "$env:AOAI_API_ENDPOINT/openai/assistants$ASSISTANT_ID?api-version=2024-02-15-preview" \
  -H "api-key: $AOAI_API_KEY" \
  -H 'content-type: application/json' \
  -d @tmp.json
rm tmp.json

$ASSISTANT_ID=((curl "$env:AOAI_API_ENDPOINT/openai/assistants?api-version=2024-02-15-preview" -H "api-key: $AOAI_API_KEY" | ConvertFrom-Json).data | Where-Object name -eq $AOAI_ASSISTANT_NAME).id

az webapp config appsettings set -g $AZURE_RESOURCE_GROUP_NAME -n $APP_NAME --settings AOAI_ASSISTANT_ID=$ASSISTANT_ID APP_URL=$APP_HOSTNAME