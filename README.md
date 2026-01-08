# AI Assistant

A Flutter mobile application that combines multiple AI-powered features including a voice assistant, image classification, document chat (RAG), and stock price prediction.

## Features

### 🎙️ Vocal Assistant
Chat with an AI assistant using voice or text. Powered by Google's Gemini AI with text-to-speech capabilities for natural conversations.

### 🖼️ Image Classification
Classify fruits and vegetables using machine learning. Supports both:
- **Gallery Upload** - Pick images from your device
- **Real-time Camera** - Live classification using your device camera (mobile only)

### 📄 Document Chat (RAG)
Upload PDF documents and ask questions about their content. Uses Retrieval-Augmented Generation to provide accurate answers based on your documents.

### 📈 Stock Prediction
Train and use an LSTM neural network model to predict stock prices with visualization of historical data and predictions.

## Tech Stack

- **Frontend**: Flutter (Android, iOS, Web)
- **Backend**: Python (FastAPI)
- **Authentication**: Firebase Auth (Email, Google, Facebook)
- **AI Services**: 
  - Google Gemini API (Chat & Image Generation)
  - TensorFlow Lite (On-device ML for image classification)
  - LSTM Model (Stock prediction)
  - LLaMA-2 (RAG document chat)

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Python 3.10+ (for backend services)
- Firebase project with Authentication enabled

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd flutter_app
   ```

2. **Set up environment variables**
   
   Create a `.env` file in the project root:
   ```
   GOOGLE_CLOUD_API_KEY=your_google_cloud_api_key
   GEMINI_API_KEY=your_gemini_api_key
   ```

3. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

4. **Set up the backend** (for RAG and Stock Prediction)
   ```bash
   cd backend
   pip install -r requirements.txt
   python rag_api.py
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── home.dart                 # Home screen
├── vocal_assistant.dart      # Voice/Chat AI assistant
├── image_classification.dart # Image classifier UI
├── stock_prediction_page.dart# Stock prediction UI
├── pages/                    # Authentication & RAG pages
└── services/                 # API and ML services

backend/
├── rag_api.py               # RAG document chat API
└── stock_prediction_service.py # Stock prediction API
```

## License

This project is for educational purposes.

