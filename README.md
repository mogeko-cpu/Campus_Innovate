# Flutter Pragmatic Clean Architecture Template 🚀

This repository provides a professional, scalable, and simplified architecture for Flutter applications using **GetX**. It follows a **Pragmatic Clean / MVVM** approach, striking a balance between strict separation of concerns and development speed.

## 🏗 Why "Pragmatic" Clean?

Traditional Clean Architecture often introduces "Use Cases" for every single action, which can feel like unnecessary boilerplate for many projects. This template simplifies the flow:

* **Strict Clean:** View → Controller → **UseCase** → Repository
* **Pragmatic Clean:** View → Controller (ViewModel) → Repository


By consolidating logic into the **Controller**, we reduce file counts while maintaining high testability and clear boundaries.

---

## 📂 Project Structure

The project is organized into layers that mirror modern software industry standards. This makes the code predictable and easy to maintain.

### 1. Domain Layer (`lib/domain`)
The "Rules" of the app. It is independent of any framework or data source.
* **Entities:** Simple Dart classes representing core objects (e.g., `User`, `Product`).
* **Repositories (Interfaces):** Abstract contracts that define what data operations are possible.

### 2. Data Layer (`lib/data`)
The "Implementation." It handles where data comes from.
* **Models:** DTOs (Data Transfer Objects) with JSON serialization logic (`fromJson`, `toJson`).
* **Sources:** Direct connections to external services (APIs via Dio, Local DBs via Hive/SharedPrefs).
* **Repositories (Implementations):** The logic that fulfills the domain contracts by calling Data Sources and mapping Models to Entities.

### 3. UI Layer (`lib/ui`)
The "Presentation."
* **Views:** Widgets and Screens. They are "dumb" and only react to state changes.
* **Viewmodels (Controllers):** GetX Controllers that manage state, handle user input, and call Repositories directly.

---

## 🛠 Dependency Injection (`main.dart`)

Dependency Injection (DI) is handled centrally in `main.dart` or via specific **Bindings**. This decouples the creation of objects from their usage, making the app modular and easy to test.

```dart
// Example of the DI flow in main.dart or Bindings
Get.lazyPut<IUserRepository>(() => UserRepositoryImpl(Get.find()));
Get.lazyPut(() => UserController(Get.find()));