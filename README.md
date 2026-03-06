<div align="center">
  <img src="assets/images/logo.png" width="150" alt="WhereDidMyTimeGo Logo" />
  <h1>WhereDid<strong>My</strong>TimeGo?</h1>
  <p><strong>An open-source, fully offline, secure time-tracking and task-planning mobile application.</strong></p>
</div>

<img src="screenshots/Home%20Page-%20Dark.jpg" width="250" align="right" alt="Home Page Dark">

## 📌 What is WhereDidMyTimeGo?
We all plan our days, but reality often goes differently. *WhereDidMyTimeGo* is designed to bridge the gap between what you *thought* you would do and what you *actually* did. With a sleek UI and easy-to-use logging mechanism, taking control of your daily routine has never been easier.

This application is completely **open source**! Feel free to fork it, modify it, compile it yourself, and adapt it to your workflow.

<br clear="both">
<hr>

## 🚀 Features

<img src="screenshots/Tasks%20Page.jpg" width="220" align="left" alt="Tasks Page" style="margin-right: 20px;">

### 📅 Plan Your Day
Schedule your tasks with an interactive and highly flexible grid interface. Plan your morning routine, your deep work blocks, and your evenings effortlessly. 

Whether you're allocating standard 30-minute chunks or sprawling 4-hour deep work sessions, the beautiful dynamic timeline neatly stacks your commitments.

<br clear="both">
<hr>

<img src="screenshots/Home%20Page-%20Lite.jpg" width="220" align="right" alt="Home Page Lite" style="margin-left: 20px;">

### ⏱ Reality Tracking
Throughout the day, the app will periodically prompt you via the notification center (e.g. every 15, 30, or 60 minutes). Did you actually finish that task, or did you get distracted? Just type your answer directly from the notification tray!

- **No app-opening required:** Reply natively via the notification panel.
- **Continuity guaranteed:** If you miss a ping, the app effortlessly copies your previous activity so there are no awkward empty gaps.
- **Log Now:** Need to log a sudden interruption? Use the bright "Log Now" button directly on the dashboard.

<br clear="both">
<hr>

<img src="screenshots/adding%20Notes.jpg" width="220" align="left" alt="Notes Page" style="margin-right: 20px;">

### 📊 Analyze It All & Manage Todos
Your dashboard dynamically compares your scheduled tasks to your actual logged activities, generating a beautiful animated feed that breaks down exactly what you accomplished today.

**📓 Scratchpad & Todos:** Jot down quick thoughts, ideas, or to-dos in the integrated Notes section without having to context-switch to another app. It helps keep your workflow smooth and uninterrupted.

<br clear="both">
<hr>

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
