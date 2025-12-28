--!strict
-- Configuration for AI suggestions. Fill in your provider info before use.
-- Never store secrets in published places; use Studio secrets or `ServerStorage`.
local AIConfig = {
    Provider = "openai",
    Endpoint = "https://api.openai.com/v1/chat/completions",
    Model = "gpt-4o-mini",
    ApiKey = "REPLACE_WITH_YOUR_KEY",
    -- Optional: Set to true to log AI requests/responses in output for debugging.
    Debug = false,
}

return AIConfig
