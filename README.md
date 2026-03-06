<div align="center">
  <img src="assets/images/logo.png" width="150" alt="WhereDidMyTimeGo Logo" />
  <h1>WhereDid<strong>My</strong>TimeGo?</h1>
</div>

**WhereDidMyTimeGo?** is an open-source, fully offline, 100% secure time-tracking and task-planning mobile application designed to help you figure out exactly where your hours vanish.

![WhereDidMyTimeGo Header](screenshots/Home%20Page-%20Dark.jpg)

## 📌 What is WhereDidMyTimeGo?
We all plan our days, but reality often goes differently. *WhereDidMyTimeGo* is designed to bridge the gap between what you *thought* you would do and what you *actually* did. With a sleek UI and easy-to-use logging mechanism, taking control of your daily routine has never been easier.

This application is completely **open source**! Feel free to fork it, modify it, compile it yourself, and adapt it to your workflow.

## 🚀 Features

### 📅 Plan Your Day
Schedule your tasks with an interactive and highly flexible grid interface. Plan your morning routine, your deep work blocks, and your evenings effortlessly.

![Tasks Page](screenshots/Tasks%20Page.jpg)

### ⏱ Reality Tracking
Throughout the day, the app will periodically prompt you via the notification center (e.g. every 15, 30, or 60 minutes). Did you actually finish that task, or did you get distracted? Just type your answer directly from the notification tray!

- **No app-opening required:** Reply natively via the notification panel.
- **Continuity guaranteed:** If you miss a ping, the app effortlessly copies your previous activity so there are no awkward empty gaps in your timeline.
- **Log Now Button:** Need to log a sudden interruption? Use the bright "Log Now" button directly on the dashboard.

### 📊 Analyze It All
Your dashboard dynamically compares your scheduled tasks to your actual logged activities.
A beautiful animated feed breaks down exactly what you accomplished today.

![Home Page Lite Mode](screenshots/Home%20Page-%20Lite.jpg)

### 📓 Scratchpad & Todos
Jot down quick thoughts or to-dos in the integrated Notes section without having to context-switch to another app.

![Adding Notes](screenshots/adding%20Notes.jpg)

### 🔒 100% Offline & Secure
All your data lives natively on your device. Period.
Your time logs are completely private. If you ever need to change devices, simply export your data to a secure file and import it securely on your new hardware.

## 💻 Tech Stack
- **Framework:** Flutter / Dart
- **State Management:** Provider
- **Storage:** SharedPreferences

## 🛠 Usage & Installation

Because this app is focused on full privacy and zero tracking, the best option is to review the code and compile it yourself!

1. **Fork the repo** and clone it to your local machine:
    ```bash
    git clone https://github.com/your-username/WhereDidMyTimeGo.git
    ```
2. **Install Dependencies:**
    ```bash
    flutter pub get
    ```
3. **Run or Build:**
    ```bash
    flutter run
    # OR build a release APK for Android
    flutter build apk --release
    ```

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! 
Feel free to check out the [issues page](../../issues).

## 📄 License
This project is completely Open Source. Fork it, improve it, and use it absolutely free of charge!
