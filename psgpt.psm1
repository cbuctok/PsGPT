<#
.Synopsis
    Invoke-PsGPT is a PowerShell module that uses the OpenAI ChatGPT API to create a chatbot that can be used in a PowerShell console.
.Description
    Invoke-PsGPT is a PowerShell module that uses the OpenAI ChatGPT API to create a chatbot that can be used in a PowerShell console.
    The module uses the OpenAI ChatGPT API to generate responses to user input. The module also saves the conversation to a JSON file.
    The module is based on the ChatGPT API example from the OpenAI API documentation.
    https://beta.openai.com/docs/api-reference/chat-completions
.EXAMPLE
    Invoke-PsGPT -filePath "C:\Users\Public\Documents\conversation.json"
    This example starts the chatbot and saves the conversation to the specified file.
#>

Function Invoke-PsGPT {
    # Get the file path for the conversation file
    param(
        [string] $filePath
    )

    function Invoke-ChatGptAPI {
        param (
            [string] $model,
            [PSCustomObject[]] $messages,
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
                [PSCustomObject]@{
                    role    = $_.role
                    content = $_.content
                }
            }
        }

        # convert messages into array
        $body.messages = @($body.messages)

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
        Write-Output "Conversation saved to $filePath."
    }

    function Get-UserInput {
        return Read-Host "user"
    }

    # Load the ChatGPT API key from an environment variable
    $apiKey = [System.Environment]::GetEnvironmentVariable("CHATGPT_API_KEY", "User")

    # Load the conversation from the file
    $conversation = Get-Conversation -filePath $filePath
    if (!$conversation) {
        $conversation = [PSCustomObject]@{
            messages = @()
        }
    }

    # Print the conversation
    $conversation.messages | ForEach-Object {
        Write-Output "$($_.role): $($_.content)"
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
            # Parse the assistant response and trim the message
            $assistantMessage = ($assistantResponse.choices | Select-Object -First 1).message
            $assistantMessage.content = $assistantMessage.content.Trim()

            # Print the message
            Write-Output "$($assistantMessage.role): $($assistantMessage.content)"

            # Add the assistant response to the conversation
            $conversation.messages += $assistantMessage
        }
    }

}
Function Invoke-ChatGptAPI {
    # Your Invoke-ChatGptAPI function code
}
Export-ModuleMember -Function Invoke-PsGPT
