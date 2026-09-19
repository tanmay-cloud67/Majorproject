# 🥗 Indian Meal Nutrition AI & Health Tracker

An AI-powered Flutter Health & Nutrition Tracking Application designed to scan Indian meals, estimate calories and macronutrients (Carbs, Protein, Fat), track water intake, activity/steps, and manage weight progress goals.

---

## 🚀 How to Run the Project

### Option 1: One-Click Quick Launch (Automated Script)

Run the included automated launch script from PowerShell or CMD:

```powershell
.\run.ps1
```
*(or double-click [`run.bat`](file:///c:/Users/vinay/health2/health/run.bat) in File Explorer)*

This script automatically:
1. Starts the Node.js backend server on port `3000`.
2. Waits 3 seconds for server initialization.
3. Launches the Flutter app in **Microsoft Edge**.

---

### Option 2: Manual Step-by-Step Launch

#### Step 1: Start the Node.js Backend Server
In your terminal, navigate to the `backend_node` folder:

```powershell
cd backend_node
npm install   # (Run once on initial setup)
node server.js
```
The backend server will run at `http://localhost:3000`.

#### Step 2: Launch the Flutter Application
Open a second terminal window in the project root directory (`c:\Users\vinay\health2\health`) and choose your target platform:

* **Web Server (Recommended - Open in any browser):**
  ```powershell
  flutter run -d web-server --web-port 8080
  ```
  *(Then open [http://localhost:8080](http://localhost:8080) in Edge, Chrome, or Firefox)*

* **Web (Chrome Browser):**
  ```powershell
  flutter run -d chrome
  ```

* **Web (Edge Browser):**
  ```powershell
  flutter run -d edge
  ```

* **Windows Desktop App:**
  ```powershell
  flutter run -d windows
  ```

* **Physical Android Device (USB Connected):**
  ```powershell
  # 1. Forward port 3000 from your phone to your PC's backend server:
  & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:3000 tcp:3000

  # 2. Run on connected Android device:
  flutter run
  ```

---

## 📱 App Architecture & Sections

The application features 5 segregated navigation sections:

1. 🏠 **Home:** Daily calorie counter, macro progress (Carbs, Protein, Fat), Calz Mascot, and weekday calendar.
2. 🏃 **Activity:** Daily movement & steps bar graph (`WeeklyStepsGraphCard`), hourly activity, and workout summary.
3. ✨ **Calz Coach (AI Scanner):** AI Meal Scanner page using computer vision for food recognition and nutrition extraction.
4. ⚖️ **Weight Progress:** Weight trend line chart, date-range goal tracking, and log entries.
5. 💧 **Wellness & Water:** Water & Hydration Tracker with quick-add buttons (`+200ml`, `+500ml`, `+1.0L`) and nutrition analytics breakdown chart.

---

## 🛠️ Helpful Flutter Commands

```powershell
# Analyze code for errors or warnings
flutter analyze

# Refresh project packages
flutter pub get

# Check connected devices
flutter devices

# Clean project cache
flutter clean
```
