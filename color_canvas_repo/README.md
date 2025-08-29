# Color Canvas (Dreamflow export)

This repository was prepared from your downloaded ZIP and is ready to push to GitHub.

**Detected stack:** flutter, firebase_functions, dart, android, ios, web

### Flutter quick start
```bash
flutter pub get
flutter run
```
### Firebase Functions (if used)
```bash
cd functions
npm install
npm run serve   # or: firebase emulators:start
```
### Environment variables
- Create a `.env` file locally for API keys and secrets. Do **not** commit it.

---

## How to publish to GitHub

Option A: GitHub Desktop → *Add local repository* → *Publish repository*.

Option B: Terminal

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<your-user>/<repo>.git
git push -u origin main
```