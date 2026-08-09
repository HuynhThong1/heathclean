# Calorie Tracking iOS App — Technical Plan

## 1. Product Goal

Build a native iOS health and calorie tracking app using Swift, SwiftUI, HealthKit, SwiftData, and Clean Architecture.

Core experience:

- User provides body information and health goal.
- App calculates BMI and a personalized daily calorie target.
- User takes a photo of a meal.
- AI recognizes visible food items and estimates portion sizes.
- Nutrition data is resolved from trusted food databases.
- User confirms or adjusts the result before saving.
- App tracks total daily kcal and macronutrients.
- App reads supported health/activity data from Apple Health.
- App warns the user when they are close to or above their daily calorie target.
- Meal history and health progress are stored locally first.

---

## 2. Core Product Principle

Do not let the AI model directly decide the final calorie value.

Recommended pipeline:

```text
Meal Photo
    ↓
Vision AI
    ↓
Food Recognition
    ↓
Portion Estimation
    ↓
Nutrition Database
    ↓
Calories + Protein + Carbs + Fat
    ↓
User Review / Correction
    ↓
Save Meal
```

Responsibilities:

```text
AI
→ Identify food items
→ Estimate serving / portion

Nutrition Database
→ Provide nutrition per 100g / serving

Domain Engine
→ Calculate calories and macros

User
→ Confirm or correct AI result
```

This design reduces hallucination, makes the AI provider replaceable, and is easier to test.

---

## 3. Recommended Tech Stack

### iOS

- Swift
- SwiftUI
- Swift Concurrency
- Observation
- SwiftData
- HealthKit
- HealthKitUI
- AVFoundation
- Vision
- UserNotifications

### Architecture

- Clean Architecture
- MVVM for Presentation
- Repository Pattern
- Protocol-based Dependency Injection
- Local-first storage

### AI

Recommended development strategy:

```text
POC / Prompt Testing
→ Gemini free tier

MVP / Self-hosted
→ Qwen3-VL-4B

Future On-device
→ Gemma 3n
```

### AI Backend

Recommended:

- Python
- FastAPI
- Hugging Face Transformers
- vLLM where applicable

### Nutrition Sources

- USDA FoodData Central
- Open Food Facts
- Custom Vietnamese Food Database

### Storage

MVP:

- SwiftData

Future:

- CloudKit

---

## 4. Main User Flow

```text
Launch
  ↓
Onboarding
  ↓
Enter Age / Height / Weight / Goal
  ↓
Connect Apple Health
  ↓
Calculate BMI
  ↓
Calculate Daily Nutrition Goal
  ↓
Dashboard
  ↓
Take Meal Photo
  ↓
AI Analysis
  ↓
Nutrition Resolution
  ↓
User Confirmation
  ↓
Save Meal
  ↓
Update Daily Calories
  ↓
Evaluate Daily Budget
  ↓
Warning if Needed
```

---

## 5. Onboarding

Collect:

- Age
- Biological sex, if needed for calorie formula
- Height
- Weight
- Target weight
- Goal
  - Lose weight
  - Maintain weight
  - Gain weight
- Activity level
- Optional dietary preferences
- Apple Health authorization

Output:

```text
BMI
Daily calorie target
Protein target
Carbohydrate target
Fat target
```

Important:

BMI should be treated as a health context indicator, not the only input used to calculate the calorie target.

Daily energy target should use additional information such as:

- age
- height
- weight
- sex
- activity level
- goal

---

## 6. Dashboard

Example:

```text
TODAY

1,320 kcal eaten

680 kcal remaining

[██████████████░░░░░░]

Target        2,000 kcal
Consumed      1,320 kcal
Remaining       680 kcal
```

Macros:

```text
Protein       92 / 140 g
Carbs        130 / 220 g
Fat           42 / 65 g
```

Activity:

```text
Steps          8,420
Active kcal      425
Sleep          7h 32m
Weight          78.5 kg
```

Meals:

```text
Breakfast      420 kcal
Lunch          680 kcal
Snack          220 kcal
Dinner           0 kcal
```

Primary CTA:

```text
Scan Your Meal
```

---

## 7. Meal Photo Flow

### Step 1 — Capture Image

Use:

- AVFoundation
- PhotosPicker
- Image compression before upload

### Step 2 — AI Analysis

AI returns structured data only.

Example:

```json
{
  "foods": [
    {
      "name": "white rice",
      "estimatedWeightGrams": 180,
      "confidence": 0.91
    },
    {
      "name": "grilled chicken",
      "estimatedWeightGrams": 140,
      "confidence": 0.86
    },
    {
      "name": "fried egg",
      "estimatedWeightGrams": 55,
      "confidence": 0.94
    }
  ]
}
```

AI should not return the final authoritative kcal.

### Step 3 — Nutrition Resolution

Example:

```text
White rice
130 kcal / 100g

Estimated serving
180g

Calories
234 kcal
```

### Step 4 — User Review

Example:

```text
AI ANALYSIS

White rice
180 g
234 kcal

Grilled chicken
140 g
231 kcal

Egg
1 serving
72 kcal

Vegetables
80 g
26 kcal

---------------------

Estimated total
563 kcal

Protein     48 g
Carbs       54 g
Fat         17 g

[ Confirm Meal ]
```

Allow user to:

- edit food name
- edit serving size
- edit weight
- remove item
- add missing item
- rescan photo

---

## 8. AI Strategy

### Option A — Qwen3-VL

Recommended for self-hosted MVP.

Suggested starting point:

```text
Qwen3-VL-4B-Instruct
```

Benefits:

- open-weight model
- vision-language capabilities
- replaceable
- can be self-hosted
- can later be fine-tuned
- avoids per-request commercial API dependency

Limitation:

```text
Free model ≠ Free infrastructure
```

GPU/server costs still exist.

Suggested prompt:

```text
Analyze this meal image.

Identify every visible food item.

Estimate portion size in grams when reasonably possible.

Do not calculate calories.

Return ONLY valid JSON matching:

{
  "foods": [
    {
      "name": "",
      "estimatedWeightGrams": 0,
      "confidence": 0
    }
  ]
}
```

---

### Option B — Gemini Free Tier

Recommended only for:

- proof of concept
- testing prompts
- testing UX
- benchmarking recognition accuracy

Do not tightly couple the app to Gemini.

Use an abstraction layer so it can be replaced later.

---

### Option C — Gemma 3n

Potential long-term on-device approach.

Possible future flow:

```text
Camera
  ↓
Gemma 3n on iPhone
  ↓
Food Recognition
  ↓
Nutrition Resolver
  ↓
Meal
```

Benefits:

- better privacy
- no image upload
- lower server dependency

Must benchmark:

- device RAM
- battery consumption
- model size
- inference latency
- older iPhone compatibility

Do not make this the first MVP implementation.

---

## 9. AI Abstraction

Domain should not know which AI model is used.

```swift
protocol FoodRecognitionRepository {
    func analyze(
        image: Data
    ) async throws -> FoodAnalysisResult
}
```

Possible implementations:

```text
GeminiFoodRecognitionRepository

QwenFoodRecognitionRepository

GemmaOnDeviceFoodRecognitionRepository
```

This allows the AI provider to change without affecting the Domain layer.

---

## 10. Nutrition Database Strategy

Use multiple providers.

### USDA FoodData Central

Best for:

- generic foods
- nutrient data
- common ingredients
- nutrient-per-100g information

### Open Food Facts

Best for:

- packaged food
- barcode scanning
- branded food
- snacks
- drinks

### Vietnamese Food Database

Build a custom local dataset for foods such as:

- cơm tấm
- phở bò
- bún bò Huế
- bánh mì thịt
- bún thịt nướng
- hủ tiếu
- gỏi cuốn
- bánh xèo
- cơm gà
- bánh cuốn

Suggested model:

```text
Food

id
name
nameEn
aliases[]

caloriesPer100g
proteinPer100g
carbsPer100g
fatPer100g

servings[]
source
```

Alias example:

```json
{
  "name": "Cơm tấm sườn",
  "aliases": [
    "com tam",
    "broken rice",
    "cơm sườn",
    "cơm tấm sườn nướng"
  ]
}
```

---

## 11. Clean Architecture

Recommended dependency direction:

```text
┌─────────────────────┐
│    Presentation     │
│ SwiftUI + ViewModel │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│       Domain        │
│ Entities            │
│ Use Cases           │
│ Repository Protocol │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│        Data         │
│ SwiftData           │
│ HealthKit           │
│ Nutrition API       │
│ AI Provider         │
└─────────────────────┘
```

Rule:

Domain should not import:

```text
SwiftUI
SwiftData
HealthKit
CoreML
AVFoundation
```

Domain should remain pure Swift.

---

## 12. Suggested Xcode Project Structure

```text
CalorieApp
│
├── App
│   ├── CalorieApp.swift
│   ├── AppRouter.swift
│   └── DependencyContainer.swift
│
├── Core
│   ├── Networking
│   ├── Storage
│   ├── Extensions
│   ├── Camera
│   ├── Logging
│   └── Utilities
│
├── Domain
│   │
│   ├── Entities
│   │   ├── UserProfile.swift
│   │   ├── NutritionGoal.swift
│   │   ├── Meal.swift
│   │   ├── FoodItem.swift
│   │   ├── FoodAnalysisResult.swift
│   │   ├── HealthSnapshot.swift
│   │   └── DailyNutritionSummary.swift
│   │
│   ├── Repositories
│   │   ├── MealRepository.swift
│   │   ├── HealthRepository.swift
│   │   ├── NutritionRepository.swift
│   │   ├── FoodRecognitionRepository.swift
│   │   └── UserRepository.swift
│   │
│   └── UseCases
│       ├── CalculateBMIUseCase.swift
│       ├── CalculateCalorieGoalUseCase.swift
│       ├── AnalyzeMealUseCase.swift
│       ├── SaveMealUseCase.swift
│       ├── GetDailySummaryUseCase.swift
│       ├── SyncHealthDataUseCase.swift
│       └── EvaluateCalorieBudgetUseCase.swift
│
├── Data
│   │
│   ├── Local
│   │   └── SwiftData
│   │
│   ├── HealthKit
│   │
│   ├── Nutrition
│   │   ├── USDA
│   │   ├── OpenFoodFacts
│   │   └── VietnameseFood
│   │
│   └── AI
│       ├── Gemini
│       ├── Qwen
│       └── Gemma
│
└── Presentation
    │
    ├── Onboarding
    ├── Dashboard
    ├── MealCamera
    ├── MealAnalysis
    ├── MealHistory
    ├── Health
    ├── Insights
    └── Profile
```

---

## 13. Core Domain Entities

### UserProfile

```swift
struct UserProfile {
    let id: UUID

    var age: Int
    var heightCm: Double
    var weightKg: Double

    var goal: WeightGoal
    var targetWeightKg: Double?
}
```

### NutritionGoal

```swift
struct NutritionGoal {
    var calories: Double

    var protein: Double
    var carbohydrates: Double
    var fat: Double
}
```

### Meal

```swift
struct Meal {
    let id: UUID

    var date: Date
    var type: MealType

    var items: [FoodItem]
}
```

### FoodItem

```swift
struct FoodItem {
    let id: UUID

    var name: String

    var weightGrams: Double

    var calories: Double

    var protein: Double
    var carbohydrates: Double
    var fat: Double

    var aiConfidence: Double?
}
```

---

## 14. HealthKit Integration

Read supported information such as:

- height
- body mass
- BMI
- step count
- active energy burned
- basal energy burned
- sleep data
- heart rate where appropriate

Optional nutrition write-back:

- dietary energy consumed
- dietary protein
- dietary carbohydrates
- dietary fat

Suggested abstraction:

```swift
protocol HealthRepository {
    func requestAuthorization() async throws

    func getWeight() async throws -> Double?

    func getActiveEnergy(
        date: Date
    ) async throws -> Double

    func getSteps(
        date: Date
    ) async throws -> Int
}
```

Implementation:

```text
HealthKitRepository
```

HealthKit authorization must be handled per data type.

The app must continue functioning even when some permissions are denied.

---

## 15. HealthKit Background Sync

Possible future implementation:

```text
Apple Watch / iPhone Activity
        ↓
HealthKit
        ↓
HKObserverQuery
        ↓
Health Repository
        ↓
SyncHealthDataUseCase
        ↓
Dashboard Update
```

Use background delivery where appropriate.

Do not design the application so that critical UI depends on background reads always being available.

---

## 16. Calorie Goal Engine

Do not implement:

```text
BMI 28
→ 2,000 kcal
```

Instead:

```text
Age
Height
Weight
Sex
Activity Level
Goal
Health Activity

        ↓

Nutrition Goal Engine

        ↓

Daily Calories
Protein
Carbohydrates
Fat
```

BMI remains useful as:

- health context
- progress indicator
- onboarding metric

---

## 17. Daily Calorie Budget

Example:

```text
Target
2,000 kcal

Breakfast
420 kcal

Lunch
750 kcal

Snack
180 kcal

Consumed
1,350 kcal

Remaining
650 kcal
```

Domain model:

```swift
struct DailyCalorieBudget {
    let target: Double
    let consumed: Double

    var remaining: Double {
        target - consumed
    }
}
```

---

## 18. Warning Engine

Recommended thresholds:

```text
0% - 69%
Normal

70%
Inform user about remaining budget

90%
Near daily target

100%
Daily target reached

>100%
Daily target exceeded
```

Example messages:

```text
You have 600 kcal remaining today.

You're close to today's calorie target.

You've reached today's calorie target.

You've exceeded today's target by 180 kcal.
```

Avoid aggressive messaging such as:

```text
STOP EATING
```

The language should be neutral and informative.

---

## 19. Notifications

Use:

```text
UserNotifications
```

Potential triggers:

- 70% of calorie budget used
- 90% reached
- target reached
- target exceeded
- optional meal logging reminder
- optional daily summary

Notification settings should be user configurable.

---

## 20. Local-first Storage

Recommended MVP data ownership:

```text
User Profile
Meal History
Weight History
Daily Nutrition Summary
Nutrition Goal

        ↓

SwiftData
```

AI service should ideally:

```text
Receive Image
Analyze
Return Structured Result
Delete Temporary Image
```

Do not persist health data on the AI server.

Future synchronization:

```text
SwiftData
   ↓
CloudKit
```

---

## 21. Privacy Strategy

Recommended:

```text
HealthKit Data
→ stays on device

Meal History
→ stays on device

Weight History
→ stays on device

Meal Image
→ temporary AI processing only
→ remove after inference
```

The product should include:

- clear privacy policy
- purpose strings for HealthKit
- minimum necessary permissions
- user-controlled permissions
- no advertising use of HealthKit data
- no health data selling
- account deletion/data deletion flow if cloud features are added later

---

## 22. AI Correction Dataset

Store AI result and confirmed user value separately.

Example:

```json
{
  "predicted": {
    "food": "white rice",
    "weight": 250
  },
  "confirmed": {
    "food": "white rice",
    "weight": 180
  }
}
```

This enables future improvements for:

- Vietnamese meal recognition
- serving size estimation
- personal meal patterns
- fine-tuning datasets
- AI evaluation

---

## 23. Personalization

Future examples:

```text
You usually log this as:
2 eggs — 144 kcal

[ Add ]
```

Possible personalization inputs:

- frequent foods
- frequent meals
- usual serving sizes
- meal times
- previous corrections
- macro goals
- weight goal
- activity pattern

This can significantly reduce the number of AI requests over time.

---

## 24. Backend Architecture

Recommended:

```text
iOS App
  │
  │ Meal Image
  ↓
AI Gateway
  │
  ├── Image Preprocessing
  │
  ├── Food Recognition Provider
  │      ├── Qwen
  │      ├── Gemini
  │      └── Future Models
  │
  ├── Nutrition Resolver
  │
  └── Nutrition Providers
         ├── USDA
         ├── Open Food Facts
         └── Vietnamese Food DB
```

Recommended implementation:

```text
Python
FastAPI
```

Python is preferred for AI workloads because of the ecosystem around:

- PyTorch
- Transformers
- vLLM
- model inference
- fine tuning
- computer vision tooling

---

## 25. API Contract

### Analyze Meal

```http
POST /v1/meals/analyze
```

Request:

```text
Content-Type: multipart/form-data

image=<meal-image>
```

Example response:

```json
{
  "items": [
    {
      "name": "Cơm trắng",
      "weight": 180,
      "calories": 234,
      "protein": 4.3,
      "carbs": 50,
      "fat": 0.4,
      "confidence": 0.92
    },
    {
      "name": "Ức gà nướng",
      "weight": 140,
      "calories": 231,
      "protein": 43,
      "carbs": 0,
      "fat": 5,
      "confidence": 0.88
    }
  ],
  "total": {
    "calories": 465,
    "protein": 47.3,
    "carbs": 50,
    "fat": 5.4
  }
}
```

The app should not care whether the server used:

- Qwen
- Gemini
- Gemma
- another future model

---

## 26. Recommended Development Phases

# Phase 1 — Core Calorie Tracker

Do not implement AI yet.

Build:

- onboarding
- user profile
- BMI calculation
- personalized daily calorie goal
- manual food entry
- meal history
- daily dashboard
- calorie progress
- warning system
- SwiftData persistence

Goal:

Validate the complete Domain model first.

---

# Phase 2 — HealthKit

Implement:

- authorization
- height
- weight
- step count
- active energy burned
- basal energy burned
- sleep data
- health snapshot
- dashboard integration

Later:

- observer queries
- background delivery

---

# Phase 3 — Nutrition Engine

Implement:

```text
NutritionRepository
```

Providers:

```text
USDAFoodRepository
OpenFoodFactsRepository
VietnameseFoodRepository
```

Normalize all providers into a single Domain type:

```text
NutritionInfo
```

Support:

- text search
- serving search
- per-100g conversion
- barcode search later

---

# Phase 4 — AI Meal Scan

Implement:

- camera
- photo picker
- image compression
- image upload
- AI gateway
- Qwen3-VL recognition
- portion estimation
- confidence score
- nutrition resolution
- review screen
- manual correction
- meal save flow

Flow:

```text
Camera
  ↓
AI
  ↓
Food Candidates
  ↓
Nutrition Resolver
  ↓
Review
  ↓
Confirm
  ↓
Save
```

---

# Phase 5 — Macro Tracking

Add:

- protein
- carbohydrates
- fat
- fiber
- optional water tracking

Dashboard:

```text
1,950 kcal

145g protein
190g carbs
65g fat
```

---

# Phase 6 — Nutrition Recommendations

Example:

```text
Consumed
1,720 / 2,000 kcal

Remaining
280 kcal
```

Recommendation logic should use:

- remaining kcal
- remaining protein
- remaining carbohydrates
- remaining fat
- dietary preferences

Start with deterministic rules before introducing another LLM.

---

# Phase 7 — Personalization

Add:

- frequent foods
- frequent meals
- favorite serving sizes
- user AI corrections
- weight trends
- calorie trends
- meal schedule
- weekly summary

---

# Phase 8 — On-device AI

Research and benchmark:

```text
Gemma 3n
+
LiteRT-LM
+
Swift
```

Target future flow:

```text
Camera
  ↓
AI on Device
  ↓
Nutrition Resolver
  ↓
Meal
```

Advantages:

- privacy
- no image upload
- reduced AI server cost
- offline possibilities

---

## 27. MVP V1 Scope

Include:

- Native SwiftUI
- Clean Architecture
- MVVM Presentation
- SwiftData
- HealthKit
- BMI
- personalized calorie target
- daily calorie tracking
- manual food entry
- meal photo capture
- AI food recognition
- estimated serving size
- kcal calculation
- protein tracking
- carbohydrate tracking
- fat tracking
- manual AI correction
- daily calorie progress
- calorie warning
- meal history
- basic weight history

Do not include initially:

- social network
- community
- AI chatbot
- advanced recipes
- dietitian marketplace
- subscription
- Android
- complex meal planner
- complex cloud infrastructure
- full multi-device synchronization

---

## 28. Suggested Initial Repository Milestones

### Milestone 1

Project bootstrap:

- Xcode project
- folders/modules
- dependency container
- navigation
- design system basics
- SwiftData setup

### Milestone 2

Domain:

- entities
- repository protocols
- BMI use case
- calorie goal use case
- calorie budget use case
- unit tests

### Milestone 3

Onboarding:

- profile form
- validation
- goal selection
- local persistence

### Milestone 4

Dashboard:

- daily summary
- calorie progress
- meal list
- warning state

### Milestone 5

Manual Meals:

- add meal
- food search
- serving editor
- meal history

### Milestone 6

HealthKit:

- permissions
- weight
- steps
- energy
- sleep
- dashboard sync

### Milestone 7

AI Backend:

- FastAPI
- `/v1/meals/analyze`
- Qwen integration
- structured JSON response
- nutrition resolver

### Milestone 8

Camera AI:

- capture image
- upload image
- loading state
- analysis screen
- correction
- save meal

### Milestone 9

Insights:

- calorie trend
- weight trend
- macro summary
- weekly health summary

---

## 29. Testing Strategy

### Domain Unit Tests

Prioritize:

- BMI calculation
- calorie goal calculation
- macro calculation
- calorie budget calculation
- warning threshold logic
- serving conversions

### Repository Tests

Mock:

- HealthKit
- AI provider
- nutrition provider
- meal storage

### AI Evaluation Dataset

Create a small test dataset containing:

- Vietnamese foods
- Western foods
- multiple-food plates
- soups
- drinks
- packaged foods
- unclear images
- partial dishes

Measure:

- food identification accuracy
- portion estimation error
- nutrition resolution success rate
- user correction rate

Do not measure AI quality only by exact kcal match.

---

## 30. Recommended Final Architecture

```text
                    ┌──────────────┐
                    │   SwiftUI    │
                    └──────┬───────┘
                           │
                       ViewModel
                           │
                           ↓
                    ┌──────────────┐
                    │   Use Case   │
                    └──────┬───────┘
                           │
                 Repository Protocols
                           │
       ┌───────────────────┼───────────────────┐
       ↓                   ↓                   ↓
   SwiftData           HealthKit         AI Repository
                                               │
                                          AI Gateway
                                               │
                               ┌───────────────┼───────────────┐
                               ↓               ↓               ↓
                           Qwen3-VL          USDA       Open Food Facts
                                                               │
                                                        Vietnamese DB
```

---

## 31. Architecture Decision Summary

Use:

```text
Native iOS
→ Swift + SwiftUI

Architecture
→ Clean Architecture + MVVM

Storage
→ SwiftData local-first

Health
→ HealthKit

AI POC
→ Gemini free tier

AI MVP
→ Qwen3-VL-4B self-hosted

Future AI
→ Gemma 3n on-device

Nutrition
→ USDA + Open Food Facts + Vietnamese Food DB

Backend
→ Python + FastAPI
```

Most important design rule:

> AI recognizes the food.  
> Nutrition databases determine nutrition values.  
> The user confirms the serving.  
> The Domain layer calculates the final calorie and macro totals.

This keeps the system testable, replaceable, privacy-aware, and suitable for long-term development.
