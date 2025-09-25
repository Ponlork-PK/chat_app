# chat_app

Flutter version used in this project is 3.35.2
Node version for the server is v24.6.0

### Client (Frontend)

| Technology |
| :--- | :--- |
| **Flutter** (Dart) | Primary framework for building the cross-platform UI. |
| **State Management** | GetX for managing application state. |
| **socket.io** | For establishing real-time connections. |

### Server (Backend)

| Component |
| :--- | :--- |
| **Server Framework** | Node.js/Express To handle API requests. |
| **WebSockets Library** | Socket.IO For persistent, real-time bidirectional communication. |

***

## Getting Started

### 1. Client Setup

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/Ponlork-PK/chat_app.git
    cd chat_app
    ```
2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the App:**
    ```bash
    flutter run
    ```
### 2. Server Setup (`server` directory)

The `server` directory contains the backend logic.

1.  **Navigate to the server directory:**
    ```bash
    cd server
    ```
2.  **Install Dependencies:**
    ```bash
    npm install
    ```
3.  **Start the Server:**
    ```bash
    node index.js
    ```

***


This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
