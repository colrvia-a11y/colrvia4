# AI Integration Setup for Color Canvas

## Setting up OpenAI API Key in DreamFlow

To enable AI-powered Color Story generation, you need to configure your OpenAI API key in Firebase Cloud Functions.

### Option 1: Using Firebase CLI (Recommended for production)
```bash
firebase functions:config:set openai.key="your-openai-api-key-here"
firebase deploy --only functions
```

### Option 2: Using Environment Variables (For local development)
Set the environment variable `OPENAI_API_KEY` in your development environment.

### Option 3: DreamFlow UI Configuration
If DreamFlow provides an AI integration interface:
1. Go to your project settings in DreamFlow
2. Look for "Integrations" or "AI Services" section
3. Add your OpenAI API key
4. Enable the AI features

## How it works

1. When a user clicks "Generate Story" in the app, the Flutter client calls the Cloud Function
2. The Cloud Function uses your OpenAI API key to generate:
   - A creative title for the color palette
   - A rich narrative description of the color story
   - Practical usage guide for each color
   - Color analysis and facets
   - Hero image description for visualization

3. If the AI service is unavailable, the app falls back to intelligent local generation

## Files created/modified:
- `/functions/index.js` - Cloud Function with OpenAI integration
- `/functions/package.json` - Updated with OpenAI dependency
- `/lib/services/ai_service.dart` - Updated to call Cloud Functions
- This README file

## Testing
After deploying the Cloud Function with your API key, test the Color Story generation feature in the app. You should see AI-generated content instead of template responses.

## API Usage
The integration uses OpenAI's GPT-3.5-turbo model for cost-effective story generation. Each story generation typically uses 1000-1500 tokens.