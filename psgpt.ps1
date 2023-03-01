function Invoke-ChatGptAPI {
  param (
    [string] $model,
    [string[]] $messages,
    [string] $apiKey
  )

  if (!$apiKey) {
    Write-Output "Error: OpenAI API Key not found in environment variables. Set the OPENAI_API_KEY environment variable with your API key."
    return
  }

  $header = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $apiKey"
  }

  $body = @{
    "model"    = $model
    "messages" = $messages
  }

  $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" -Method POST -Headers $header -Body (ConvertTo-Json $body)

  return $response
}


# Load the ChatGPT API key from an environment variable
$apiKey = [System.Environment]::GetEnvironmentVariable("CHATGPT_API_KEY", "User")

# Get the file path for the conversation file
$filePath = $args[0]

# If the file does not exist, create an empty conversation file
if (-not (Test-Path $filePath)) {
  New-Item -Path $filePath -ItemType File -Force
}

# Load the conversation from the file
$conversation = Get-Content $filePath | ConvertFrom-Json

# Main loop to wait for user input
while ($true) {
  # Get user input
  $userInput = Read-Host "Enter a message (or a command):"
  
  # Check if the input is a command
  if ($userInput -eq "/save") {
    # Save the conversation to the file
    $conversation | ConvertTo-Json | Set-Content $filePath
    Write-Host "Conversation saved to $filePath."
  }
  elseif ($userInput -eq "/exit") {
    # Exit the script
    break
  }
  elseif ($userInput -eq "/wq") {
    # Save the conversation and exit the script
    $conversation | ConvertTo-Json | Set-Content $filePath
    Write-Host "Conversation saved to $filePath."
    break
  }
  else {
    # Add the user input to the conversation
    $conversation.messages += [PSCustomObject]@{
      role    = "user"
      content = $userInput
    }
  
    # Call the ChatGPT API
    Invoke-ChatGptAPI -model "gpt-3.5-turbo" -messages $conversation.messages.content -apiKey $apiKey | ForEach-Object {
      # Add the assistant response to the conversation
      $conversation.messages += [PSCustomObject]@{
        role    = "assistant"
        content = $_.choices[0].text
      }
    }
  }
}


  