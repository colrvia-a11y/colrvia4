// Add/keep existing imports
import * as functions from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import admin from "firebase-admin";
import { Storage } from "@google-cloud/storage";
import textToSpeech from "@google-cloud/text-to-speech";
import { z } from "zod";
import { generate } from "@genkit-ai/googleai";
// (others unchanged)

admin.initializeApp();
const db = admin.firestore();
const storage = new Storage();
const ttsClient = new textToSpeech.TextToSpeechClient();

// ✅ Input validation schemas
const PaletteItem = z.object({
  hex: z.string().regex(/^#[0-9A-Fa-f]{6}/),
  brandName: z.string().optional(),
  name: z.string().optional(),
  code: z.string().optional(),
});

const ModernPalette = z.object({
  id: z.string().optional(),
  name: z.string().default("Untitled"),
  items: z.array(PaletteItem).min(1, "Palette items cannot be empty"),
});

const InputSchema = z.object({
  // Modern format
  palette: ModernPalette.optional(),

  // Legacy format
  paletteName: z.string().optional(),
  colors: z.array(z.string().regex(/^#[0-9A-Fa-f]{6}/)).optional(),

  // Common
  room: z.string(),
  style: z.string(),
  vibeWords: z.array(z.string()).default([]),
  brandHints: z.array(z.string()).default([]),
});

const USAGE_ITEM = z.object({
  role: z.string(),
  hex: z.string().regex(/^#[0-9A-Fa-f]{6}/),
  name: z.string(),
  brandName: z.string(),
  code: z.string(),
  surface: z.string(),
  finishRecommendation: z.string(),
  sheen: z.string(),
  howToUse: z.string()
});
const USAGE_GUIDE = z.array(USAGE_ITEM).min(4).max(6);

async function uploadBuffer(path, buffer, contentType) {
  const parsed = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : null;
  const bucketName = parsed?.storageBucket || admin.app().options.storageBucket;
  const bucket = storage.bucket(bucketName);
  const file = bucket.file(path);
  await file.save(buffer, { contentType, resumable: false, public: true, validation: false });
  await file.makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${path}`;
}

function gradientHeroSvg(hexes) {
  const a = (hexes?.[0] || "#888888");
  const b = (hexes?.[1] || "#444444");
  return Buffer.from(
`<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="${a}"/><stop offset="100%" stop-color="${b}"/></linearGradient></defs>
  <rect width="1600" height="900" fill="url(#g)"/></svg>`
  );
}

async function writeProgress(docRef, status, progress, message) {
  await docRef.set({
    status, progress, progressMessage: message,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
}

// ✅ Normalize modern or legacy into one shape
function normalizePalette(data) {
  if (data?.palette?.items?.length) {
    const p = data.palette;
    return {
      id: p.id ?? null,
      name: p.name ?? "Untitled",
      items: p.items,
      hexes: p.items.map(i => i.hex),
    };
  }
  if (
    Array.isArray(data?.colors) &&
    data.colors.length > 0 &&
    typeof data?.paletteName === "string" &&
    data.paletteName.trim().length > 0
  ) {
    const items = data.colors.map(hex => ({ hex }));
    return {
      id: null,
      name: data.paletteName.trim(),
      items,
      hexes: data.colors,
    };
  }
  // Standardized error for clients
  throw new functions.https.HttpsError(
    "invalid-argument",
    "Provide a palette with colors: either palette.items[] or paletteName + colors[] (list of hex strings)."
  );
}

// ✅ Ownership validation guard wrapper
function requireOwner(ctx, story) {
  if (!ctx.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (story.ownerId !== ctx.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Not your story');
  }
}

export const generateColorStory = onCall({ region: "us-central1" }, async (req) => {
  try {
    // 🐛 DEBUG: Log initial request
    const uid = req.auth?.uid;
    logger.info("generateColorStory: Starting", { 
      uid, 
      hasAuth: !!req.auth, 
      dataKeys: Object.keys(req.data || {}),
      rawData: req.data 
    });
    
    if (!uid) {
      logger.error("generateColorStory: No authentication");
      throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }
    
    // 🐛 DEBUG: Validate input schema
    let input;
    try {
      input = InputSchema.parse(req.data);
      logger.info("generateColorStory: Schema validation passed", { input });
    } catch (schemaError) {
      logger.error("generateColorStory: Schema validation failed", { 
        error: schemaError.message, 
        issues: schemaError.issues || [],
        data: req.data 
      });
      throw new functions.https.HttpsError("invalid-argument", `Invalid input: ${schemaError.message}`);
    }
    
    // 🐛 DEBUG: Normalize palette
    let norm;
    try {
      norm = normalizePalette(input);
      logger.info("generateColorStory: Palette normalized", { 
        normId: norm.id,
        normName: norm.name,
        hexesCount: norm.hexes?.length || 0,
        itemsCount: norm.items?.length || 0
      });
    } catch (normalizeError) {
      logger.error("generateColorStory: Palette normalization failed", { 
        error: normalizeError.message,
        input 
      });
      throw new functions.https.HttpsError("invalid-argument", `Palette normalization error: ${normalizeError.message}`);
    }
    
    const { room, style, vibeWords = [], brandHints = [] } = input;
    
    // 🐛 DEBUG: Check all required fields are strings
    const debugInfo = {
      room: { value: room, type: typeof room, isNull: room === null },
      style: { value: style, type: typeof style, isNull: style === null },
      normName: { value: norm.name, type: typeof norm.name, isNull: norm.name === null },
      vibeWordsLength: vibeWords?.length || 0,
      brandHintsLength: brandHints?.length || 0
    };
    logger.info("generateColorStory: Field validation", debugInfo);
    
    // Convert null values to safe strings
    const safeRoom = room || "living room";
    const safeStyle = style || "modern";
    const safeName = norm.name || "Untitled Palette";
    const safeVibeWords = Array.isArray(vibeWords) ? vibeWords : [];
    const safeBrandHints = Array.isArray(brandHints) ? brandHints : [];
    
    logger.info("generateColorStory: Using safe values", {
      safeRoom,
      safeStyle,
      safeName,
      safeVibeWordsCount: safeVibeWords.length,
      safeBrandHintsCount: safeBrandHints.length
    });
    
    // Create single Firestore document
    const docRef = db.collection("colorStories").doc();
    
    logger.info("generateColorStory: Creating Firestore document", { 
      docId: docRef.id,
      uid,
      normId: norm.id,
      room: safeRoom,
      style: safeStyle
    });
    
    // Initialize document with all required fields
    await docRef.set({
      id: docRef.id,
      ownerId: uid,
      name: safeName,
      sourcePaletteId: norm.id || null,
      palette: norm,
      room: safeRoom,
      style: safeStyle,
      vibeWords: safeVibeWords,
      brandHints: safeBrandHints,
      access: "private",
      status: "processing",
      progress: 0.1,
      progressMessage: "Starting generation…",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    logger.info("generateColorStory: Initial document created successfully");

    try {
      // 1) Generate Narration using Genkit/Gemini
      await writeProgress(docRef, "processing", 0.3, "Writing narration…");
      
      // 🐛 DEBUG: Build narration prompt with safe values
      const narrationPrompt = `You are an interior color expert. Write 300–600 words for a ${safeRoom} in ${safeStyle} style.
Vibe words: ${safeVibeWords.join(", ")}.
Brand hints: ${safeBrandHints.join(", ")}.
Use these paints (hex + brand/name/code if provided): ${JSON.stringify(norm.hexes || [])}.
Explain role placement (main/trim/ceiling/accent/door/cabinet), finish & sheen, and simple lighting tips.
Tone: warm, expert, practical.`;

      logger.info("generateColorStory: Calling Gemini for narration", { 
        promptLength: narrationPrompt.length,
        model: "models/gemini-1.5-pro-latest"
      });
      
      const narrationRes = await generate({ 
        model: "models/gemini-1.5-pro-latest", 
        input: [{ text: narrationPrompt }] 
      });
      
      logger.info("generateColorStory: Gemini narration response", { 
        hasOutput: !!narrationRes?.output,
        outputLength: narrationRes?.output?.length || 0,
        hasContent: !!narrationRes?.output?.[0]?.content,
        contentLength: narrationRes?.output?.[0]?.content?.length || 0
      });
      
      const narration = narrationRes?.output?.[0]?.content?.[0]?.text || "";
      logger.info("generateColorStory: Extracted narration", { 
        narrationLength: narration.length 
      });
      
      await docRef.set({ 
        narration, 
        modelAttribution: { 
          provider: "Google", 
          model: "Gemini 1.5 Pro", 
          promptVersion: "v1" 
        } 
      }, { merge: true });
      logger.info("generateColorStory: Narration saved to Firestore");

      // 2) Generate Usage Guide using Genkit/Gemini
      await writeProgress(docRef, "processing", 0.5, "Building usage guide…");
      
      const ugPrompt = `Return STRICT JSON array (4–6 items), no prose.
Each item keys: role, hex, name, brandName, code, surface, finishRecommendation, sheen, howToUse.
Match room=${safeRoom}, style=${safeStyle}, vibe=${safeVibeWords.join(", ")}, brands=${safeBrandHints.join(", ")} and provided palette.
Roles should include main, trim, ceiling, accent and add door/cabinet if present.`;

      logger.info("generateColorStory: Generating usage guide", { 
        promptLength: ugPrompt.length 
      });
      
      let usageGuide = [];
      try {
        const ugRes = await generate({ 
          model: "models/gemini-1.5-pro-latest", 
          input: [{ text: ugPrompt }] 
        });
        const raw = ugRes?.output?.[0]?.content?.[0]?.text || "[]";
        
        logger.info("generateColorStory: Raw usage guide response", { 
          rawLength: raw.length,
          rawPreview: raw.substring(0, 200)
        });
        
        const parsed = JSON.parse(raw);
        usageGuide = USAGE_GUIDE.parse(parsed);
        
        logger.info("generateColorStory: Usage guide parsed successfully", { 
          itemCount: usageGuide.length 
        });
      } catch (ugError) {
        logger.error("generateColorStory: Usage guide generation failed", { 
          error: ugError.message 
        });
        usageGuide = [];
      }
      await docRef.set({ usageGuide }, { merge: true });
      logger.info("generateColorStory: Usage guide saved to Firestore");

      // 3) Generate Hero Image using Genkit/Gemini Flash 2.5
      await writeProgress(docRef, "processing", 0.7, "Rendering hero image…");
      
      const hexes = norm.hexes || [];
      const heroPrompt = `Ultra-realistic interior photograph of a ${safeRoom} in ${safeStyle} style.
Natural daylight, clean staging, wide angle (~24mm), f/4.
Palette applied subtly on appropriate surfaces: ${hexes.join(", ")}.
Mood: ${safeVibeWords.join(", ")}.
No people, no text, no logos. 1600x900 composition.`;

      logger.info("generateColorStory: Generating hero image", { 
        hexesCount: hexes.length,
        promptLength: heroPrompt.length 
      });
      
      let heroImageUrl = null;
      try {
        const imgRes = await generate({ 
          model: "models/gemini-flash-2.5", 
          input: [{ text: heroPrompt }] 
        });
        
        logger.info("generateColorStory: Gemini image response", { 
          hasOutput: !!imgRes?.output,
          outputLength: imgRes?.output?.length || 0
        });
        
        const inline = imgRes?.output?.[0]?.content?.find(p => p?.inlineData)?.inlineData;
        const b64 = inline?.data || imgRes?.output?.[0]?.content?.[0]?.image?.data;
        
        if (b64) {
          const bytes = Buffer.from(b64, "base64");
          heroImageUrl = await uploadBuffer(`color_stories/heroes/${docRef.id}.jpg`, bytes, "image/jpeg");
          logger.info("generateColorStory: Hero image uploaded successfully", { heroImageUrl });
          
          await docRef.set({
            heroImageUrl, heroPrompt,
            heroImageAttribution: { 
              provider: "Google", 
              model: "Gemini Flash 2.5", 
              seed: inline?.mimeType || null 
            }
          }, { merge: true });
        } else {
          throw new Error("No image data received from Gemini");
        }
      } catch (heroError) {
        logger.warn("generateColorStory: Hero image generation failed, using fallback", { 
          error: heroError.message 
        });
        
        const svg = gradientHeroSvg(hexes);
        heroImageUrl = await uploadBuffer(`color_stories/heroes/${docRef.id}.svg`, svg, "image/svg+xml");
        await docRef.set({ 
          heroImageUrl, 
          heroPrompt, 
          heroImageAttribution: { provider: "fallback", model: "gradient" } 
        }, { merge: true });
        
        logger.info("generateColorStory: Fallback hero image created", { heroImageUrl });
      }

      // 4) Generate Audio using Google Cloud TTS
      await writeProgress(docRef, "processing", 0.9, "Mixing audio…");
      
      logger.info("generateColorStory: Generating audio", { 
        narrationLength: narration.length 
      });
      
      const [tts] = await ttsClient.synthesizeSpeech({
        input: { text: narration || "This color story is ready for you." },
        voice: { languageCode: "en-US", name: "en-US-Neural2-C" },
        audioConfig: { audioEncoding: "MP3" }
      });
      
      const audioUrl = await uploadBuffer(`color_stories/audio/${docRef.id}.mp3`, tts.audioContent, "audio/mpeg");
      await docRef.set({ 
        audioUrl, 
        audioAttribution: { provider: "Google Cloud TTS", voice: "en-US-Neural2-C" } 
      }, { merge: true });
      
      logger.info("generateColorStory: Audio generated successfully", { audioUrl });

      await writeProgress(docRef, "complete", 1.0, "Story ready");
      logger.info("generateColorStory: COMPLETE - returning storyId", { storyId: docRef.id });
      
      // ✅ Return success with correct storyId format
      const response = { storyId: docRef.id };
      logger.info("generateColorStory: Final response", { response });
      return response;

    } catch (generationError) {
      logger.error("generateColorStory: Generation pipeline error", { 
        error: generationError.message,
        stack: generationError.stack,
        docId: docRef?.id
      });
      
      if (docRef) {
        try {
          await writeProgress(docRef, "error", 0, generationError?.message || "Generation failed");
        } catch (progressError) {
          logger.error("generateColorStory: Failed to write error progress", { error: progressError.message });
        }
      }
      
      throw new functions.https.HttpsError("internal", generationError?.message || "Color story generation failed");
    }

  } catch (outerError) {
    logger.error("generateColorStory: Top-level error", { 
      error: outerError.message,
      stack: outerError.stack,
      code: outerError.code,
      type: typeof outerError
    });
    
    // Re-throw HttpsError with proper code structure
    if (outerError.code && outerError.message) {
      throw outerError;
    }
    
    // Convert unknown errors to HttpsError
    throw new functions.https.HttpsError(
      "internal", 
      outerError.message || "Unexpected error during color story generation"
    );
  }
});

export const generateColorStoryVariant = onCall({ region: "us-central1" }, async (req) => {
  try {
    const uid = req.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated","Login required.");
    const { storyId, emphasis = "", vibeTweaks = [] } = req.data;
    const parentSnap = await db.collection("colorStories").doc(storyId).get();
    if (!parentSnap.exists) throw new functions.https.HttpsError("not-found", "Story not found.");
    const p = parentSnap.data();
    
    // ✅ Validate ownership of parent story
    requireOwner(req, p);

    const docRef = db.collection("colorStories").doc();
    await docRef.set({
      ownerId: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      access: "private",
      status: "processing",
      progress: 0.1,
      progressMessage: "Starting…",
      sourcePaletteId: p.sourcePaletteId,
      variantOf: storyId,
      room: p.room, style: p.style, vibeWords: [...(p.vibeWords || []), emphasis, ...vibeTweaks]
    }, { merge: true });

    try {
      // Re-run the same pipeline but reusing parent's palette hexes:
      const palette = { id: p.sourcePaletteId, hexes: (p.usageGuide || []).map(u => u.hex) };
      const room = p.room;
      const style = p.style;
      const vibeWords = [...(p.vibeWords || []), emphasis, ...vibeTweaks].filter(Boolean);

      // 1) Narration with variant emphasis
      await writeProgress(docRef, "processing", 0.3, "Writing variant narration…");
      const narrationPrompt = `You are an interior color expert. Write 300–600 words for a ${room} in ${style} style.
This is a VARIANT with emphasis on: ${emphasis}.
Vibe words: ${vibeWords.join(", ")}.
Use these paints (hex + brand/name/code if provided): ${JSON.stringify(palette.hexes)}.
Explain role placement (main/trim/ceiling/accent/door/cabinet), finish & sheen, and simple lighting tips.
Focus on the variant emphasis: ${emphasis}.
Tone: warm, expert, practical.`;
      const narrationRes = await generate({ model: "models/gemini-1.5-pro-latest", input: [{ text: narrationPrompt }] });
      const narration = narrationRes?.output?.[0]?.content?.[0]?.text ?? "";
      await docRef.set({ narration, modelAttribution: { provider: "Google", model: "Gemini 1.5 Pro", promptVersion: "v1-variant" } }, { merge: true });

      // 2) Usage Guide (strict JSON) with variant focus
      await writeProgress(docRef, "processing", 0.5, "Building variant usage guide…");
      const ugPrompt = `Return STRICT JSON array (4–6 items), no prose.
Each item keys: role, hex, name, brandName, code, surface, finishRecommendation, sheen, howToUse.
Match room=${room}, style=${style}, emphasis="${emphasis}", vibe=${vibeWords.join(", ")} and provided palette.
Roles should include main, trim, ceiling, accent and add door/cabinet if present.
Focus on variant emphasis: ${emphasis}.`;
      let usageGuide = [];
      try {
        const ugRes = await generate({ model: "models/gemini-1.5-pro-latest", input: [{ text: ugPrompt }] });
        const raw = ugRes?.output?.[0]?.content?.[0]?.text ?? "[]";
        const parsed = JSON.parse(raw);
        usageGuide = USAGE_GUIDE.parse(parsed);
      } catch {
        usageGuide = [];
      }
      await docRef.set({ usageGuide }, { merge: true });

      // 3) Hero Image (Gemini Flash 2.5) with variant emphasis and fallback gradient
      await writeProgress(docRef, "processing", 0.7, "Rendering variant hero image…");
      const hexes = palette.hexes || [];
      const heroPrompt = `Ultra-realistic interior photograph of a ${room} in ${style} style.
Variant emphasis: ${emphasis}.
Natural daylight, clean staging, wide angle (~24mm), f/4.
Palette applied subtly on appropriate surfaces: ${hexes.join(", ")}.
Mood: ${vibeWords.join(", ")}.
Special focus: ${emphasis}.
No people, no text, no logos. 1600x900 composition.`;
      let heroImageUrl = null;
      try {
        const imgRes = await generate({ model: "models/gemini-flash-2.5", input: [{ text: heroPrompt }] });
        const inline = imgRes?.output?.[0]?.content?.find(p => p?.inlineData)?.inlineData;
        const b64 = inline?.data || imgRes?.output?.[0]?.content?.[0]?.image?.data;
        const bytes = Buffer.from(b64, "base64");
        heroImageUrl = await uploadBuffer(`color_stories/heroes/${docRef.id}.jpg`, bytes, "image/jpeg");
        await docRef.set({
          heroImageUrl, heroPrompt,
          heroImageAttribution: { provider: "Google", model: "Gemini Flash 2.5", seed: inline?.mimeType ?? null }
        }, { merge: true });
      } catch {
        const svg = gradientHeroSvg(hexes);
        heroImageUrl = await uploadBuffer(`color_stories/heroes/${docRef.id}.svg`, svg, "image/svg+xml");
        await docRef.set({ heroImageUrl, heroPrompt, heroImageAttribution: { provider: "fallback", model: "gradient" } }, { merge: true });
      }

      // 4) Audio (TTS) for variant narration
      await writeProgress(docRef, "processing", 0.9, "Mixing variant audio…");
      const [tts] = await ttsClient.synthesizeSpeech({
        input: { text: narration },
        voice: { languageCode: "en-US", name: "en-US-Neural2-C" },
        audioConfig: { audioEncoding: "MP3" }
      });
      const audioUrl = await uploadBuffer(`color_stories/audio/${docRef.id}.mp3`, tts.audioContent, "audio/mpeg");
      await docRef.set({ audioUrl, audioAttribution: { provider: "Google Cloud TTS", voice: "en-US-Neural2-C" } }, { merge: true });

      await writeProgress(docRef, "complete", 1.0, "Variant ready");
      return { success: true, storyId: docRef.id };

    } catch (err) {
      await writeProgress(docRef, "error", 0, (err?.message ?? "Variant error"));
      throw new functions.https.HttpsError("internal", err?.message ?? "Unknown variant error");
    }
  } catch (error) {
    functions.logger.error("generateColorStoryVariant error:", error);
    if (error.code) {
      throw error; // Re-throw HttpsError with proper code
    }
    return { 
      error: true, 
      message: error.message || "Unknown error occurred" 
    };
  }
});

export const retryStoryStep = onCall({ region: "us-central1" }, async (req) => {
  try {
    const uid = req.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Login required.");
    
    const { storyId, step } = req.data;
    if (!storyId || !step) {
      throw new functions.https.HttpsError("invalid-argument", "storyId and step are required");
    }
    
    const storySnap = await db.collection("colorStories").doc(storyId).get();
    if (!storySnap.exists) {
      throw new functions.https.HttpsError("not-found", "Story not found");
    }
    
    const story = storySnap.data();
    
    // ✅ Validate ownership
    requireOwner(req, story);
    
    const docRef = db.collection("colorStories").doc(storyId);
    
    // Validate step is one of: 'writing', 'usage', 'hero', 'audio'
    const validSteps = ['writing', 'usage', 'hero', 'audio'];
    if (!validSteps.includes(step)) {
      throw new functions.https.HttpsError("invalid-argument", `Invalid step. Must be one of: ${validSteps.join(', ')}`);
    }
    
    // Set status to processing with specific step progress
    const stepProgress = {
      'writing': 0.3,
      'usage': 0.5,
      'hero': 0.7,
      'audio': 0.9
    };
    
    const progressMessage = {
      'writing': 'Retrying narration...',
      'usage': 'Retrying usage guide...',
      'hero': 'Retrying hero image...',
      'audio': 'Retrying audio...'
    };
    
    await writeProgress(docRef, "processing", stepProgress[step], progressMessage[step]);
    
    try {
      const room = story.room || "living room";
      const style = story.style || "modern";
      const vibeWords = story.vibeWords || [];
      const brandHints = story.brandHints || [];
      const palette = story.palette || { hexes: [] };
      const hexes = palette.hexes || [];
      
      if (step === 'writing') {
        // Retry narration generation
        const narrationPrompt = `You are an interior color expert. Write 300–600 words for a ${room} in ${style} style.
Vibe words: ${vibeWords.join(", ")}.
Brand hints: ${brandHints.join(", ")}.
Use these paints (hex + brand/name/code if provided): ${JSON.stringify(hexes)}.
Explain role placement (main/trim/ceiling/accent/door/cabinet), finish & sheen, and simple lighting tips.
Tone: warm, expert, practical.`;

        const narrationRes = await generate({ 
          model: "models/gemini-1.5-pro-latest", 
          input: [{ text: narrationPrompt }] 
        });
        
        const narration = narrationRes?.output?.[0]?.content?.[0]?.text || "";
        await docRef.set({ 
          narration, 
          modelAttribution: { 
            provider: "Google", 
            model: "Gemini 1.5 Pro", 
            promptVersion: "v1-retry" 
          } 
        }, { merge: true });
        
      } else if (step === 'usage') {
        // Retry usage guide generation
        const ugPrompt = `Return STRICT JSON array (4–6 items), no prose.
Each item keys: role, hex, name, brandName, code, surface, finishRecommendation, sheen, howToUse.
Match room=${room}, style=${style}, vibe=${vibeWords.join(", ")}, brands=${brandHints.join(", ")} and provided palette.
Roles should include main, trim, ceiling, accent and add door/cabinet if present.`;

        let usageGuide = [];
        try {
          const ugRes = await generate({ 
            model: "models/gemini-1.5-pro-latest", 
            input: [{ text: ugPrompt }] 
          });
          const raw = ugRes?.output?.[0]?.content?.[0]?.text || "[]";
          const parsed = JSON.parse(raw);
          usageGuide = USAGE_GUIDE.parse(parsed);
        } catch (ugError) {
          logger.error("retryStoryStep: Usage guide retry failed", { error: ugError.message });
          usageGuide = [];
        }
        await docRef.set({ usageGuide }, { merge: true });
        
      } else if (step === 'hero') {
        // Retry hero image generation
        const heroPrompt = `Ultra-realistic interior photograph of a ${room} in ${style} style.
Natural daylight, clean staging, wide angle (~24mm), f/4.
Palette applied subtly on appropriate surfaces: ${hexes.join(", ")}.
Mood: ${vibeWords.join(", ")}.
No people, no text, no logos. 1600x900 composition.`;

        let heroImageUrl = null;
        try {
          const imgRes = await generate({ 
            model: "models/gemini-flash-2.5", 
            input: [{ text: heroPrompt }] 
          });
          
          const inline = imgRes?.output?.[0]?.content?.find(p => p?.inlineData)?.inlineData;
          const b64 = inline?.data || imgRes?.output?.[0]?.content?.[0]?.image?.data;
          
          if (b64) {
            const bytes = Buffer.from(b64, "base64");
            heroImageUrl = await uploadBuffer(`color_stories/heroes/${storyId}.jpg`, bytes, "image/jpeg");
            await docRef.set({
              heroImageUrl, heroPrompt,
              heroImageAttribution: { 
                provider: "Google", 
                model: "Gemini Flash 2.5", 
                seed: inline?.mimeType || null 
              }
            }, { merge: true });
          } else {
            throw new Error("No image data received from Gemini");
          }
        } catch (heroError) {
          logger.warn("retryStoryStep: Hero retry failed, using fallback", { error: heroError.message });
          const svg = gradientHeroSvg(hexes);
          heroImageUrl = await uploadBuffer(`color_stories/heroes/${storyId}.svg`, svg, "image/svg+xml");
          await docRef.set({ 
            heroImageUrl, 
            heroPrompt, 
            heroImageAttribution: { provider: "fallback", model: "gradient" } 
          }, { merge: true });
        }
        
      } else if (step === 'audio') {
        // Retry audio generation
        const narration = story.narration || "This color story is ready for you.";
        const [tts] = await ttsClient.synthesizeSpeech({
          input: { text: narration },
          voice: { languageCode: "en-US", name: "en-US-Neural2-C" },
          audioConfig: { audioEncoding: "MP3" }
        });
        
        const audioUrl = await uploadBuffer(`color_stories/audio/${storyId}.mp3`, tts.audioContent, "audio/mpeg");
        await docRef.set({ 
          audioUrl, 
          audioAttribution: { provider: "Google Cloud TTS", voice: "en-US-Neural2-C" } 
        }, { merge: true });
      }
      
      // Mark step as complete - don't change overall status unless this was the final step
      const currentStatus = story.status;
      if (currentStatus !== 'complete') {
        await writeProgress(docRef, currentStatus, stepProgress[step] + 0.05, `${step} step completed`);
      }
      
      logger.info(`retryStoryStep: Successfully retried ${step} for story ${storyId}`);
      
      return { 
        success: true, 
        step, 
        message: `${step} step completed successfully` 
      };
      
    } catch (retryError) {
      logger.error(`retryStoryStep: ${step} retry failed`, { 
        error: retryError.message,
        storyId,
        step
      });
      
      await writeProgress(docRef, "error", stepProgress[step], `${step} retry failed: ${retryError.message}`);
      throw new functions.https.HttpsError("internal", `${step} retry failed: ${retryError.message}`);
    }
    
  } catch (error) {
    logger.error("retryStoryStep error:", error);
    if (error.code) {
      throw error; // Re-throw HttpsError with proper code
    }
    throw new functions.https.HttpsError("internal", error.message || "Unknown error occurred");
  }
});

export { USAGE_GUIDE, uploadBuffer, gradientHeroSvg, writeProgress, db, ttsClient, generate, admin, functions };