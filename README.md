# 🚖 White Cabs Project

The **White Cabs Project** is a Flutter-based cab management system for admins and customers.  
It helps manage vehicles, drivers, trips, and invoices, while also allowing customers to **download invoices in PDF format**.

---

## ✨ Features

### For Admins
- 🚗 **Vehicle Management** – Add, edit, and track vehicles  
- 👨‍✈️ **Driver Management** – Store driver details like license & contact  
- 📅 **Trip Management** – Assign or reassign trips with details  
- 📊 **Dashboard** – View trips, income, and driver/vehicle status  
- 🧾 **End Trip & Billing** – Auto-calculate trip costs & generate invoices  

### For Customers
- 🆔 **Unique Booking ID** – Every booking has a unique ID  
- 📥 **Invoice Download** – Download invoices in **PDF** format  
- 📲 **SMS Notifications** – Receive trip updates  
- 💰 **Transparent Billing** – Full breakdown of charges  

---

## 🛠 Tech Stack

- **Flutter** – Cross-platform app framework  
- **SQLite (sqflite)** – Local database with migrations  
- **Provider** – State management for UI updates  
- **Path Provider** – File & image storage paths  
- **Image Picker** – Upload driver/vehicle photos  
- **PDF Generation** – Create invoices in PDF  

---

## 📂 Project Structure (Simplified)

lib/
├── models/ # Data models (Driver, Vehicle, Trip, Invoice)
├── services/ # Database, Invoice, API, SMS services
├── screens/ # UI Screens (Dashboard, Trip, Driver, Vehicle, Invoice)
├── widgets/ # Reusable UI widgets
└── main.dart # Entry point
---

## 🔄 State Management

The app uses **Provider** for state management:  
- When the database changes (e.g., new driver added), the **UI updates automatically**.  
- Example: Ending a trip → DB updates → Provider notifies → Dashboard refreshes instantly.  

---

## 📸 Screenshots

### 🏠 Home Screen
![Home Screen](assets/screenshots/Home%20Screen.jpeg)

### 👨‍✈️ Drivers Screen
![Drivers Screen](assets/screenshots/Drivers%20Screen.jpeg)

### 🚗 Vehicles Screen
![Vehicles Screen](assets/screenshots/Vechiles%20Screen.jpeg)

---

## 👨‍💻 Author
Developed by **Harihareswaran**  
