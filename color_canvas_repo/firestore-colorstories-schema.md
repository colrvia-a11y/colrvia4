# Color Stories Firestore Schema

## Collection: `colorStories`

### Document Structure

```typescript
{
  title: string,                    // required - Display title
  slug: string,                     // required - URL-safe identifier
  heroImageUrl?: string,            // optional - Featured image URL
  themes: string[],                 // array - e.g., ["coastal", "modern-farmhouse", "traditional"]
  families: string[],               // array - e.g., ["greens", "blues", "neutrals", "warm-neutrals", "cool-neutrals"]
  rooms: string[],                  // array - e.g., ["kitchen", "living", "bedroom", "exterior"]
  tags: string[],                   // array - mood/season keywords
  description: string,              // required - Short story description
  isFeatured: boolean,              // default: false
  createdAt: Timestamp,             // auto-set on create
  updatedAt: Timestamp,             // auto-set on edit
  palette: [                        // array of 3-6 palette items
    {
      role: string,                 // "main" | "accent" | "trim" | "ceiling" | "door" | "cabinet"
      hex: string,                  // e.g., "#4A6A5A"
      paintId?: string,             // optional - references paints collection
      brandName?: string,           // optional - e.g., "Sherwin-Williams"
      name?: string,                // optional - paint name
      code?: string,                // optional - paint code
      psychology?: string,          // optional - short benefit description
      usageTips?: string            // optional - how/where to use this color
    }
  ]
}
```

## Required Firestore Indexes

### Composite Indexes (Required for Array Queries + Ordering)

1. **Featured Stories with Theme Filter**
   ```
   Collection: colorStories
   Fields: 
     - isFeatured (Descending)
     - createdAt (Descending)
     - themes (Arrays)
   ```

2. **Featured Stories with Family Filter**
   ```
   Collection: colorStories
   Fields:
     - isFeatured (Descending) 
     - createdAt (Descending)
     - families (Arrays)
   ```

3. **Featured Stories with Room Filter**
   ```
   Collection: colorStories
   Fields:
     - isFeatured (Descending)
     - createdAt (Descending) 
     - rooms (Arrays)
   ```

4. **Multi-Array Filter Support** (if needed)
   ```
   Collection: colorStories
   Fields:
     - themes (Arrays)
     - families (Arrays)
     - isFeatured (Descending)
     - createdAt (Descending)
   ```

### Single-Field Indexes (Auto-created)
- `slug` (for unique lookups)
- `isFeatured` (for featured filtering)
- `createdAt` (for time-based ordering)

## Example Data

```json
{
  "title": "Coastal Serenity",
  "slug": "coastal-serenity",
  "heroImageUrl": "https://images.unsplash.com/photo-coastal-room",
  "themes": ["coastal", "modern"],
  "families": ["blues", "neutrals"],
  "rooms": ["living", "bedroom", "kitchen"],
  "tags": ["calming", "summer", "ocean-inspired"],
  "description": "Embrace the tranquil essence of coastal living with this soothing palette that brings the ocean indoors.",
  "isFeatured": true,
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "palette": [
    {
      "role": "main",
      "hex": "#4A90A4",
      "paintId": "sw-6220",
      "brandName": "Sherwin-Williams",
      "name": "Oceanside",
      "code": "SW 6220",
      "psychology": "Promotes calm and focus",
      "usageTips": "Perfect for main walls in living spaces"
    },
    {
      "role": "accent",
      "hex": "#F5F5DC",
      "paintId": "bm-2143-60", 
      "brandName": "Benjamin Moore",
      "name": "Moonlight",
      "code": "2143-60",
      "psychology": "Creates warm, welcoming atmosphere",
      "usageTips": "Use for trim and ceiling highlights"
    },
    {
      "role": "trim",
      "hex": "#FFFFFF",
      "brandName": "Generic",
      "name": "Pure White",
      "psychology": "Adds brightness and contrast",
      "usageTips": "Classic choice for baseboards and window frames"
    }
  ]
}
```

## Query Examples

### Get Featured Stories
```dart
final stories = await FirebaseService.getColorStories(
  isFeatured: true,
  limit: 10,
);
```

### Filter by Themes
```dart
final coastalStories = await FirebaseService.getColorStories(
  themes: ['coastal', 'modern-farmhouse'],
  limit: 20,
);
```

### Filter by Rooms and Color Families
```dart
final kitchenNeutrals = await FirebaseService.getColorStories(
  rooms: ['kitchen'],
  families: ['neutrals', 'warm-neutrals'],
  limit: 15,
);
```

### Stream Featured Stories (Live Updates)
```dart
StreamBuilder<List<ColorStory>>(
  stream: FirebaseService.streamFeaturedColorStories(limit: 5),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ListView.builder(
        itemCount: snapshot.data!.length,
        itemBuilder: (context, index) {
          final story = snapshot.data![index];
          return ColorStoryCard(story: story);
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

## Usage in Flutter App

### Data Models
- `ColorStory` - Main document model
- `ColorStoryPalette` - Individual palette item model

### Service Methods
- `getColorStories()` - Query with filters
- `getColorStoryById()` - Get single story by ID
- `getColorStoryBySlug()` - Get single story by slug
- `streamFeaturedColorStories()` - Live featured stories
- `streamAllColorStories()` - Live all stories
- `createColorStory()` - Admin: Create new story
- `updateColorStory()` - Admin: Update existing story
- `deleteColorStory()` - Admin: Delete story

## Performance Considerations

1. **Index Management**: Ensure all composite indexes are created before deployment
2. **Query Limits**: Default limits prevent excessive reads (configurable per query)
3. **Array Filtering**: Uses `arrayContainsAny` for efficient multi-value searches
4. **Caching**: Implement client-side caching for frequently accessed featured stories
5. **Pagination**: Consider implementing cursor-based pagination for large result sets

## Security Rules Example

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Color Stories - read-only for authenticated users, admin write
    match /colorStories/{storyId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
  }
}
```

This schema provides a robust, scalable foundation for the Color Stories feature with efficient querying capabilities and proper indexing for production use.