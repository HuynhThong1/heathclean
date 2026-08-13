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

---

## 32. Locket-style History — Kế hoạch triển khai

### 32.1 Mục tiêu trải nghiệm

Nâng cấp tab **Lịch sử** từ danh sách theo tuần thành một “bản đồ ký ức ăn uống”
theo tháng, lấy cảm hứng từ cách Locket đặt ảnh lên lịch. Người dùng có thể nhìn
lướt qua cả tháng, nhận ra ngày nào đã ghi món, chạm vào ảnh để xem lại bữa ăn và
thêm bữa cho ngày phù hợp mà không làm mất các số liệu dinh dưỡng hiện có.

Điểm học từ màn hình tham chiếu:

- mỗi tháng là một card lớn, cuộn dọc liên tục; tháng hiện tại nằm trên cùng;
- lưới 7 cột giữ đúng vị trí ngày trong tuần, nhưng ưu tiên ảnh hơn con số;
- ngày có ảnh dùng thumbnail bo góc, ngày đã qua nhưng trống dùng chấm nhỏ, ngày
  còn lại có thể là ô trống; ngày được chọn/add có trạng thái viền nổi bật;
- ảnh là điểm vào chi tiết, còn tiêu đề tháng và khoảng trống giúp người dùng cảm
  nhận “timeline” thay vì một date picker thuần túy.

Không sao chép nhận diện thương hiệu, màu sắc hay gamification của Locket. Giao
diện tiếp tục dùng font và token `DS.*` của HeathFirst, đồng thời giữ calorie,
macro và loại bữa ăn là nội dung chính.

### 32.2 Phạm vi sản phẩm

#### MVP

1. Tab Lịch sử mở ở tháng hiện tại và cuộn ngược về các tháng có dữ liệu.
2. Mỗi ngày chỉ có một ô trong lưới Monday-first:
   - có bữa kèm ảnh: hiển thị ảnh gần nhất trong ngày;
   - có nhiều ảnh: thêm badge số lượng;
   - có bữa nhưng không có ảnh: hiển thị tile theo loại bữa và tổng kcal;
   - ngày đã qua không có dữ liệu: hiển thị chấm trung tính;
   - ngày tương lai: không tương tác và không hiển thị chấm.
3. Chạm một ngày mở **day sheet** gồm tổng kcal/macro và các bữa theo thời gian.
   Chạm một bữa tiếp tục dùng `MealDetailView` hiện có.
4. Nút “+” trong ngày hôm nay mở luồng ghi bữa/scan hiện có. MVP không cho ghi
   lùi ngày để tránh thay đổi ngữ nghĩa của dashboard, notification và HealthKit.
5. Có skeleton khi tải, empty state cho người dùng mới, retry state khi đọc dữ
   liệu thất bại và VoiceOver label đầy đủ cho từng ngày.
6. Lịch sử dạng tuần hiện tại được thay bằng lịch tháng; không duy trì hai cách
   điều hướng song song trong MVP.

#### Sau MVP

- bộ lọc theo loại bữa, món ăn hoặc nguồn nhập (thủ công/AI);
- tìm kiếm theo tên món;
- chế độ chọn nhiều ảnh để chia sẻ recap tháng;
- heatmap dinh dưỡng và streak, chỉ triển khai sau khi xác nhận chúng không tạo
  áp lực tiêu cực về ăn uống;
- ghi bữa cho ngày quá khứ sau khi thống nhất quy tắc đồng bộ HealthKit và báo cáo.

### 32.3 Quy tắc UX chi tiết

- **Lịch:** Gregorian, locale `vi_VN`, tuần bắt đầu từ Thứ Hai và dùng múi giờ tự
  động của thiết bị, nhất quán với `MealHistoryModel` hiện tại.
- **Tháng hiện tại:** chỉ hiển thị đến hôm nay; không tạo cảm giác ngày tương lai
  là dữ liệu bị thiếu. Tháng cũ hiển thị đủ số ngày.
- **Thumbnail đại diện:** lấy ảnh của meal mới nhất trong ngày; nếu meal đó có
  nhiều ảnh thì lấy ảnh đầu tiên. Quy tắc phải deterministic để tránh ảnh đổi vị
  trí sau mỗi lần render.
- **Ngày được chọn:** viền `DS` accent và có nhãn ngày; không chỉ dựa vào màu để
  truyền đạt trạng thái.
- **Tương tác:** toàn bộ ô ngày có hit target tối thiểu 44×44 pt. Không dùng
  horizontal swipe để đổi tháng vì xung đột với back gesture và khó khám phá.
- **Cuộn:** tải ban đầu tháng hiện tại cộng hai tháng trước; khi gần cuối danh sách
  tải thêm ba tháng. Giữ vị trí cuộn khi dữ liệu refresh hoặc quay lại từ detail.
- **Ảnh lỗi/mất:** fallback sang tile dinh dưỡng, không để ô trắng và không coi là
  lỗi tải toàn màn hình.
- **Quyền riêng tư:** ảnh bữa ăn chỉ lưu local trong MVP, không đưa vào iCloud,
  analytics hay backend. Xóa meal phải xóa ảnh không còn được tham chiếu.

### 32.4 Thay đổi mô hình dữ liệu

Domain không giữ `UIImage` hoặc đường dẫn filesystem. Thêm metadata độc lập nền
tảng vào `Meal`, dự kiến:

```swift
public struct MealPhoto: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var capturedAt: Date
    public var pixelWidth: Int
    public var pixelHeight: Int
}

public struct Meal {
    // Existing fields...
    public var photos: [MealPhoto]
}
```

App layer chịu trách nhiệm ánh xạ `MealPhoto.id` sang file. Tạo
`MealPhotoStore` actor với `save`, `thumbnail`, và `delete`; ảnh gốc dùng JPEG/HEIC
đã sửa orientation, thumbnail dùng kích thước cố định phù hợp màn hình @3x. Ghi
file theo chiến lược temp → atomic rename, sau đó mới lưu metadata để tránh entity
trỏ vào file chưa hoàn tất.

SwiftData thêm `MealPhotoEntity` quan hệ cascade từ `MealEntity`. Migration phải
coi `photos` là mảng rỗng mặc định để toàn bộ meal cũ tiếp tục đọc được. Khi xóa,
repository trả/ghi nhận photo IDs cần dọn và `MealPhotoStore` thực hiện cleanup;
một tác vụ bảo trì nhẹ có thể xóa orphan file khi khởi động.

Ảnh từ scan chỉ được gắn vào meal **sau khi người dùng xác nhận lưu**. Ảnh camera
tạm phải bị xóa khi hủy luồng scan. Bữa nhập thủ công không bắt buộc có ảnh.

### 32.5 API và phân lớp

Giữ dependency direction hiện tại:

```text
MealHistoryView
  -> MealHistoryModel
    -> GetMealHistoryMonthsUseCase
      -> MealRepository
        -> SwiftDataMealRepository

MealHistoryView / Scan flow
  -> MealPhotoStore (App-only file adapter)
```

Mở rộng repository bằng truy vấn phân trang theo khoảng tháng, không gọi một
query cho từng ngày. Use case trả về value types sẵn sàng cho presentation:

```swift
HistoryMonth(yearMonth, days: [HistoryDay])
HistoryDay(date, meals, totalNutrition, representativePhotoID)
```

`GetMealHistoryMonthsUseCase` chịu trách nhiệm day boundary, group/sort meal,
thumbnail representative và tổng dinh dưỡng. View model chỉ quản lý paging,
selection, loading/error state và chống kết quả request cũ ghi đè request mới.

### 32.6 Cấu trúc UI đề xuất

```text
App/Presentation/MealHistory/
├── MealHistoryView.swift          # container, navigation, paging trigger
├── MealHistoryModel.swift         # state của các tháng đã tải
├── HistoryMonthCard.swift         # header + weekday row + calendar grid
├── HistoryDayTile.swift           # photo/fallback/dot/future states
└── HistoryDaySheet.swift          # nutrition summary + meal list
```

`HistoryMonthCard` dùng `LazyVGrid` 7 cột cố định. Placeholder đầu/cuối tháng vẫn
chiếm cell nhưng accessibility hidden để ngày khớp đúng thứ. Dùng thumbnail cache
theo `photoID + targetSize + displayScale`; hủy task decode khi tile rời màn hình
và không decode ảnh gốc trên main actor.

Accessibility identifiers ổn định:

- `history.month.YYYY-MM`
- `history.day.YYYY-MM-DD`
- `history.day.photo.YYYY-MM-DD`
- `history.day.add.YYYY-MM-DD`
- `history.day.sheet`
- `history.loadMore`

VoiceOver label của ô ngày gồm ngày đầy đủ, số bữa, tổng kcal và trạng thái có
ảnh. Dynamic Type không làm thay đổi 7 cột; khi chữ lớn, ẩn text phụ trong tile
nhưng giữ toàn bộ nội dung ở accessibility label.

### 32.7 Các giai đoạn triển khai

#### Giai đoạn 0 — Product/visual spike

- dựng wireframe cho tháng hiện tại, tháng cũ, empty/loading/error và day sheet;
- chốt kích thước tile trên iPhone SE và màn hình Pro Max;
- xác nhận “một ảnh đại diện/ngày” và phạm vi nút add;
- đo prototype với 12–24 tháng dữ liệu giả trước khi chốt kiến trúc cache.

**Exit:** design review duyệt interaction, token và accessibility annotations.

#### Giai đoạn 1 — Domain query và lịch tháng

- thêm các value type/use case tổng hợp theo tháng;
- bổ sung truy vấn range và unit tests cho ranh giới tháng/năm, leap day, DST,
  locale và nhiều meal trong cùng ngày;
- dựng calendar grid bằng fallback tile, chưa cần ảnh;
- thay week strip sau feature flag nội bộ `historyMonthGrid`.

**Exit:** xem và mở được mọi meal cũ; paging không query theo từng ngày.

#### Giai đoạn 2 — Photo persistence

- thêm `MealPhoto`, SwiftData migration và `MealPhotoStore`;
- nối ảnh đã capture từ scan vào meal được xác nhận;
- tạo thumbnail background, cache có giới hạn và cleanup khi cancel/delete;
- bổ sung privacy/storage notes trong app nếu cần.

**Exit:** relaunch vẫn thấy đúng thumbnail; xóa meal không để orphan; meal cũ
không ảnh vẫn hoạt động.

#### Giai đoạn 3 — Day sheet và hoàn thiện trải nghiệm

- thêm summary kcal/macro, danh sách meal và navigation tới detail;
- loading skeleton, retry, empty state, badge nhiều ảnh, scroll restoration;
- localization tiếng Việt/Anh và VoiceOver/Dynamic Type/Reduce Motion;
- analytics tối thiểu, không chứa ảnh hay tên món: mở History, chọn ngày, mở meal,
  paging month, lỗi thumbnail.

**Exit:** đạt acceptance criteria và UI test chạy ổn định trên simulator mục tiêu.

#### Giai đoạn 4 — Rollout

- bật feature flag cho nội bộ/TestFlight trước;
- theo dõi crash-free sessions, thời gian render tháng đầu, memory peak, tỷ lệ lỗi
  thumbnail và dung lượng ảnh;
- rollout tăng dần; giữ khả năng tắt remote flag trong một phiên bản phát hành;
- xóa UI tuần cũ và flag sau khi bản lịch tháng ổn định.

### 32.8 Kế hoạch kiểm thử

#### Domain/Repository

- nhóm đúng ngày/tháng ở ranh giới 23:59–00:00 và DST;
- thứ tự tháng mới → cũ, meal theo thời gian và ảnh đại diện deterministic;
- tháng 28/29/30/31 ngày, tháng bắc cầu năm;
- tổng calorie/macro không thay đổi khi meal có/không có ảnh;
- migration store cũ, cascade metadata và cleanup orphan file;
- request paging trùng nhau không tạo duplicate hoặc để response cũ thắng.

#### UI/XCUITest

- mở History ở tháng hiện tại và không chọn được ngày tương lai;
- seed meal có ảnh, không ảnh và nhiều meal để kiểm tra ba tile state;
- chạm ngày → day sheet → meal detail → sửa/xóa → grid refresh đúng;
- cuộn tải tháng cũ, quay lại vẫn giữ scroll position;
- empty/error/retry, VoiceOver identifiers và cỡ chữ accessibility;
- đo scroll với ít nhất 24 tháng × 10 ảnh/tháng, theo dõi hitch và memory warning.

### 32.9 Acceptance criteria MVP

- tháng đầu có nội dung hữu ích xuất hiện trong ≤ 500 ms với local fixture trên
  simulator mục tiêu; không block main thread để decode ảnh;
- scroll 24 tháng không crash, không tăng bộ nhớ không giới hạn và không thấy ảnh
  của ngày khác do cell reuse;
- mọi meal hiện có vẫn truy cập/sửa/xóa được từ day sheet;
- dữ liệu calorie/macro của lịch khớp dashboard cho cùng ngày;
- ngày tương lai không tương tác; ngày trống, ngày có meal không ảnh và ngày có
  ảnh phân biệt được cả bằng VoiceOver;
- ảnh không rời thiết bị trong MVP; cancel và delete dọn file đúng quy tắc;
- `swift test` và các XCUITest History cũ được cập nhật/chạy xanh trước rollout.

### 32.10 Rủi ro và quyết định cần chốt

| Rủi ro/câu hỏi | Hướng xử lý đề xuất |
|---|---|
| Ảnh làm tăng dung lượng app | Nén khi lưu, thumbnail riêng, hiển thị dung lượng trong Settings ở phase sau |
| SwiftData metadata và file lệch nhau | Atomic file write, cleanup orphan, test crash giữa hai bước |
| Lưới 7 cột quá nhỏ | Photo-first, text tối thiểu, day sheet cho chi tiết, kiểm thử máy nhỏ |
| Lịch dài gây giật | Range fetch theo batch, `LazyVStack`, thumbnail cache giới hạn |
| Meal scan hiện chưa lưu ảnh | Giai đoạn 2 là dependency bắt buộc để đạt visual giống tham chiếu |
| Có cho thêm/sửa ngày cũ không | MVP chỉ add hôm nay; sửa/xóa meal cũ vẫn giữ như hiện tại |
| Một ngày nhiều meal hiển thị gì | Ảnh meal mới nhất + badge số ảnh; day sheet hiển thị đầy đủ |
| Đồng bộ/iCloud | Ngoài MVP; local-only phải được truyền đạt rõ trước khi người dùng đổi máy |

Quyết định product cần xác nhận trước Giai đoạn 1: (1) có thay hoàn toàn week strip
hay rollout song song, (2) có cho ghi bữa quá khứ, và (3) retention/chất lượng ảnh
gốc. Mặc định của kế hoạch này lần lượt là **thay thế sau feature flag**, **không**,
và **giữ ảnh nén local cho đến khi meal bị xóa**.
