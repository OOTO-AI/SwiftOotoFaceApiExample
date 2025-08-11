# OOTO Face API — iOS Demo (UIKit + Storyboard)

A **minimal demonstration** app showing how to integrate iOS with **OOTO Face API** services.  
This project is for evaluation and learning only (not production).

---

## What this demo does

- **Take photo** — opens the camera and shows a preview.
- **Enroll** — sends the captured photo to create a face template.
- **Search** — performs 1:N face identification against existing templates.
- **Delete** — deletes a template by `templateId` (appears after you get one from Enroll or Search).

---

## API endpoints used

All requests include `APP-ID` and `APP-KEY` HTTP headers.

- **Enroll** — `POST /add`  
  - Query (optional): `check_liveness=true|false`, `check_deepfake=true|false`  
  - Body: `multipart/form-data` with:
    - `photo`: JPEG/PNG file
    - `templateId` (optional): string
- **Search (Identify)** — `POST /identify`  
  - Query (optional): `check_liveness=true|false`, `check_deepfake=true|false`  
  - Body: `multipart/form-data` with:
    - `photo`: JPEG/PNG file
- **Delete** — `POST /delete`  
  - Body: JSON
    ```json
    { "templateId": "<ID>" }
    ```

**Notes**
- On successful **Search**, the app displays `templateId` and `similarity`.
- If the backend indicates no detectable face, the app shows **No faces found**.
- **Delete** is **manual** via button (not automatic).

---

## Requirements

- Xcode 14+  
- iOS 13+ (uses SceneDelegate)  
- Real device for camera testing (the iOS Simulator camera isn’t supported)  
- OOTO credentials: `APP-ID`, `APP-KEY`

---

## Project structure

```
OotoFaceApiExample/
├─ OotoFaceApiExample.xcodeproj
├─ OotoFaceApiExample/
│  ├─ AppDelegate.swift
│  ├─ SceneDelegate.swift
│  ├─ APIConstants.swift        // Base URL, endpoints, APP-ID/APP-KEY
│  ├─ APIClient.swift           // Enroll / Identify / Delete requests
│  ├─ Models/
│  │  ├─ IdentifyResponse.swift // Identify + generic API error models
│  │  └─ DeleteResponse.swift   // DeleteRequest / DeleteSuccessResponse
│  ├─ ViewController.swift      // Camera + buttons + result handling
│  ├─ Base.lproj/Main.storyboard
│  ├─ Assets.xcassets/
│  └─ Info.plist
└─ README.md
```

---

## Setup

1. **Clone**
   ```bash
   git clone https://github.com/OOTO-AI/SwiftOotoFaceApiExample.git
   cd SwiftOotoFaceApiExample
   ```

2. **Open in Xcode**  
   Open `OotoFaceApiExample.xcodeproj`.

3. **Configure credentials**  
   Edit `APIConstants.swift`:
   ```swift
   struct APIConstants {
       static let baseURL = URL(string: "https://cloud.ooto-ai.com/api/v1.0")!
       static let identifyEndpoint = "/identify"
       static let addTemplateEndpoint = "/add"
       static let deleteEndpoint = "/delete"

       static let appId  = "<YOUR_APP_ID>"
       static let appKey = "<YOUR_APP_KEY>"
   }
   ```

4. **Camera permission**  
   Ensure `Info.plist` contains:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera access is required to take a face photo.</string>
   ```

5. **Run on device**  
   Select a physical iPhone target and press **⌘R**.

---

## Usage (UI flow)

- Launch screen shows: **Take photo**, **Enroll** (disabled), **Search** (disabled).  
- Tap **Take photo** → capture → preview appears → **Enroll** and **Search** become enabled.  
- Tap **Enroll** → calls `/add` → shows returned `templateId` → **Delete** appears.  
- Tap **Search** → calls `/identify` → shows `templateId` + `similarity` if matched → **Delete** appears.  
- Tap **Delete** → calls `/delete` with the last `templateId` → shows result.

---

## Implementation details

- **Networking**: `URLSession`.  
  - Enroll & Search: manual `multipart/form-data` body with `photo`.  
  - Delete: `application/json` body (`{"templateId":"..."}`).  
- **UI**: UIKit + Storyboard (single `UIViewController`).  
  - **Take photo**: full-width row.  
  - **Enroll** & **Search**: one row, equal widths.  
  - **Delete**: separate row, hidden until a `templateId` exists.  
  - Results `UILabel` is multiline with wrapping for long IDs.
- **Concurrency**: main-thread UI updates, simple activity indicator, buttons disabled during in-flight requests.

---

## Error handling

- Network issues → `Network error: <message>`.
- API errors → server `info` message is shown.
- “No faces found” when the backend signals no detectable face.
- Defensive UI guards to avoid crashes if an IBOutlet is accidentally disconnected during storyboard edits.

---

## License

MIT
