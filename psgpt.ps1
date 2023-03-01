function Invoke-ChatGptAPI {
  param (
    [string] $model,
    [string[]] $messages,
    [string] $apiKey
  )

  if (!$apiKey) {
    Write-Output "Error: OpenAI API Key not found in environment variables. Set the CHATGPT_API_KEY environment variable with your API key."
    return
  }

  $header = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $apiKey"
  }

  $body = @{
    "model"    = $model
    "messages" = $messages | ForEach-Object {
      @{
        role    = if( Get-Member -InputObject $ -Name "role") { $.role}  else { "user" }
        content = if( Get-Member -InputObject $ -Name "content") { $.content}  else { "hello" }
      }
    }
  } 

  $json = $body | ConvertTo-Json
  
  $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" -Method POST -Headers $header -Body $json

  return $response
}

function Get-Conversation {
  param (
    [string] $filePath
  )

  if (-not (Test-Path $filePath)) {
    New-Item -Path $filePath -ItemType File -Force
  }

  $conversation = Get-Content $filePath | ConvertFrom-Json

  return $conversation
}

function Save-Conversation {
  param (
    [string] $filePath,
    [object] $conversation
  )

  $conversation | ConvertTo-Json | Set-Content $filePath
  Write-Host "Conversation saved to $filePath."
}

function Get-UserInput {
  return Read-Host "Enter a message (or a command):"
}

# Load the ChatGPT API key from an environment variable
$apiKey = [System.Environment]::GetEnvironmentVariable("CHATGPT_API_KEY", "User")

# Get the file path for the conversation file
$filePath = $args[0]

# Load the conversation from the file
$conversation = Get-Conversation -filePath $filePath
if (!$conversation) {
  $conversation = [PSCustomObject]@{
    messages = @()
  }
}

# Main loop to wait for user input
while ($true) {
  # Get user input
  $userInput = Get-UserInput

  # Check if the input is a command
  if ($userInput -eq "/save") {
    # Save the conversation to the file
    Save-Conversation -filePath $filePath -conversation $conversation
  }
  elseif ($userInput -eq "/exit") {
    # Exit the script
    break
  }
  elseif ($userInput -eq "/wq") {
    # Save the conversation and exit the script
    Save-Conversation -filePath $filePath -conversation $conversation
    break
  }
  else {
    # Add the user input to the conversation
    $conversation.messages += [PSCustomObject]@{
      role    = "user"
      content = $userInput
    }
  
    # Call the ChatGPT API
    $assistantResponse = Invoke-ChatGptAPI -model "gpt-3.5-turbo" -messages $conversation.messages -apiKey $apiKey
    # Add the assistant response to the conversation
    $conversation.messages += [PSCustomObject]@{
      role    = "assistant"
      content = $assistantResponse
    }
  }
}
