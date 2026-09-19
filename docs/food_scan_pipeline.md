# Food Scan Pipeline

## Goal

Move the food scanner from a single weak guess into a staged pipeline:

1. Capture image from camera
2. Segment food from plate/background
3. Classify the cropped food region
4. Show top 3 matches
5. Add calories and save after user confirmation

## Why this helps

The current broad scanner works as plain image classification. That means the model sees:

- plate
- table
- shadows
- side dishes
- background clutter

Food segmentation can remove a lot of that noise before classification.

## Recommended pipeline

### Stage 1: Capture

- Use `image_picker` camera flow
- Save the full image path
- Keep the original image for the Food Log preview

### Stage 2: Segmentation

Use a segmentation model to isolate food regions before classification.

Best use of `FoodSeg103`:

- segment food pixels from background
- detect multiple ingredients / food regions
- crop the largest food region first
- if multiple strong regions exist, classify more than one region

Important:

- `FoodSeg103-Benchmark-v1-main.zip` is benchmark code, not the full dataset
- the actual `FoodSeg103` dataset must be downloaded separately if we train our own segmenter

### Stage 3: Classification

Current strongest broad benchmark:

- Hugging Face model `dima806/indian_food_image_detection`
- benchmarked on our 80-class split at:
  - top-1: `75.75%`
  - top-3: `92.75%`
  - top-5: `95.25%`

Use classification on:

- the segmented crop first
- fallback to the original full image if segmentation fails

### Stage 4: Candidate ranking

UI should show:

- top 3 food matches
- confidence per match
- calories for each match

Recommended behavior:

- confidence >= `0.85`: allow direct quick-add
- confidence `0.60` to `0.84`: show top 3 suggestions and ask user to choose
- confidence < `0.60`: ask for retry

### Stage 5: Nutrition lookup

After classification:

- map label -> calories from local JSON / CSV
- keep nutrition lookup separate from the classifier
- this lets us swap models without changing calorie logic

### Stage 6: Save to log

When the user confirms:

- save selected food name
- save calories
- save original captured image path
- update Food Log UI immediately

## Suggested app architecture

Use the pipeline abstractions in:

- [food_scan_pipeline.dart](/C:/Users/vinay/health2/health/lib/services/food_scan_pipeline.dart)

Suggested concrete implementations:

- `LocalFoodSegmenter`
- `HfFoodClassifier` or converted mobile classifier
- `JsonNutritionLookup`

## Best practical rollout order

1. Replace single-result UI with top-3 candidate UI
2. Use the stronger broad classifier as the default prediction source
3. Add segmentation before classification
4. Add portion/weight estimation later

## Honest expectation

Segmentation should improve real scan quality, especially on cluttered photos, but it will not guarantee `85%+` top-1 by itself.

The most realistic next target is:

- make the broad scanner feel reliable with top-3 confirmation
- then improve true top-1 with better crops and better data
