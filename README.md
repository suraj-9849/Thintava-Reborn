# Thintava-Reborn

Thintava-Reborn is a modern solution designed to streamline canteen management by eliminating the need for manual token systems. With this application, users can receive real-time notifications from all canteens, making the process efficient, transparent, and user-friendly. The system is easy to implement and can be adapted to various canteen environments with minimal setup.

## Features
- **No More Manual Tokens:** Automates the entire token system, reducing human error and saving time.
- **Real-Time Notifications:** Users receive instant updates from all canteens, ensuring they never miss important information.
- **Easy Implementation:** The solution is designed for quick and hassle-free deployment in any canteen.
- **Scalable:** Suitable for single or multiple canteen setups.
- **Cross-Platform:** Works seamlessly across Android, iOS, web, and desktop platforms.

## Getting Started

### Prerequisites
- [Flutter](https://flutter.dev/docs/get-started/install) installed on your machine
- [Firebase](https://firebase.google.com/) project setup (for notifications and backend)
- Node.js (for cloud functions)

### Installation
1. **Clone the repository:**
	```bash
	git clone https://github.com/Thintava/Thintava-Reborn.git
	cd Thintava-Reborn
	```
2. **Install dependencies:**
	```bash
	flutter pub get
	cd functions
	npm install
	cd ..
	```
3. **Configure Firebase:**
	- Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files to the respective directories.
	- Update `firebase.json` and other configuration files as needed.

4. **Run the app:**
	```bash
	flutter run
	```

## Usage
- Register or log in to the app.
- Select your canteen and view real-time notifications.
- No need to collect or manage physical tokens.

## Project Structure
- `lib/` - Main Flutter application code
- `functions/` - Firebase Cloud Functions (Node.js)
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` - Platform-specific code
- `assets/` - Images and other assets

## Technologies Used
- Flutter
- Firebase (Firestore, Cloud Functions, Messaging)
- Node.js

## Contributing
Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact
For questions or support, please open an issue in the repository.
