// File: src-tauri/src/main.rs
#![cfg_attr(
  all(not(debug_assertions), target_os = "windows"),
  windows_subsystem = "windows"
)]

mod llm_provider;
use llm_provider::{LLMProvider, GroqProvider, AppRequest, LLMResponse, ProviderRequest};
use tauri::State;
use std::collections::HashMap;
use std::sync::Arc;

// This struct defines what an Archetype is: a system prompt and a specific model.
struct Archetype {
    system_prompt: String,
    model_name: String,
    provider: Arc<dyn LLMProvider + Send + Sync>,
}

// The AppState now holds a map of all available archetypes.
struct AppState {
    archetypes: HashMap<String, Archetype>,
}

#[tauri::command]
async fn ask_guardian(
    request: AppRequest, // The UI sends the full request object
    state: State<'_, AppState>,
) -> Result<LLMResponse, String> {
    // 1. Find the requested archetype in our map.
    let archetype = state.archetypes.get(&request.archetype)
        .ok_or_else(|| format!("Archetype '{}' not found.", request.archetype))?;

    // 2. Combine our core system prompt with the user's custom prompt.
    let mut full_prompt_content = archetype.system_prompt.clone();
    if let Some(user_prompt) = &request.user_system_prompt {
        full_prompt_content.push_str("\n\n--- User's Instructions ---\n");
        full_prompt_content.push_str(user_prompt);
    }
    full_prompt_content.push_str("\n\n--- User's Prompt ---\n");
    full_prompt_content.push_str(&request.prompt);

    // 3. Create the final request for the provider.
    let provider_request = ProviderRequest {
        full_prompt: full_prompt_content,
        model_name: archetype.model_name.clone(),
    };

    // 4. Call the provider associated with the archetype.
    archetype.provider
         .ask(&provider_request)
         .await
         .map_err(|e| e.to_string())
}

fn main() {
    // It's recommended to use a tool like `dotenvy` to load environment variables
    // For this example, we'll use `std::env` directly.
    // Ensure you have a .env file in `src-tauri` with GROQ_API_KEY="your-key"
    dotenvy::dotenv().expect("Failed to load .env file. Please create a .env file in the src-tauri directory.");
    let groq_api_key = std::env::var("GROQ_API_KEY").expect("GROQ_API_KEY must be set in your .env file");

    // Create instances of all the providers we support.
    let groq_provider = Arc::new(GroqProvider::new(groq_api_key));

    // Create our map of archetypes. This is where we define our "modes".
    let mut archetypes = HashMap::new();
    archetypes.insert("Scout".to_string(), Archetype {
        system_prompt: "You are the Scout. You are fast, versatile, and conversational. Perfect for quick questions, brainstorming, and daily dialogue.".to_string(),
        model_name: "llama3-8b-8192".to_string(),
        provider: Arc::clone(&groq_provider),
    });
    archetypes.insert("Architect".to_string(), Archetype {
        system_prompt: "You are the Architect. You are logical, structured, and deep. Ideal for planning, analysis, and complex problem-solving.".to_string(),
        model_name: "llama3-70b-8192".to_string(),
        provider: Arc::clone(&groq_provider),
    });

    let app_state = AppState { archetypes };

    tauri::Builder::default()
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![ask_guardian])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
