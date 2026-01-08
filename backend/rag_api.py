from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import os
from PyPDF2 import PdfReader
from langchain_text_splitters import CharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough
import tempfile
import uvicorn
import base64
import io
import numpy as np
from PIL import Image
import tensorflow as tf
from stock_prediction_service import stock_service

app = FastAPI(title="RAG Chatbot API")

# CORS configuration to allow Flutter web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global storage for vector stores and chains per session
sessions = {}

# Load CNN model at startup
cnn_model = None
# 36 classes - ALPHABETICALLY SORTED (ImageDataGenerator default)
class_labels = [
    'apple', 'banana', 'beetroot', 'bell pepper', 'cabbage',
    'capsicum', 'carrot', 'cauliflower', 'chilli pepper', 'corn',
    'cucumber', 'eggplant', 'garlic', 'ginger', 'grapes',
    'jalepeno', 'kiwi', 'lemon', 'lettuce', 'mango',
    'onion', 'orange', 'paprika', 'pear', 'peas',
    'pineapple', 'pomegranate', 'potato', 'raddish', 'soy beans',
    'spinach', 'sweetcorn', 'sweetpotato', 'tomato', 'turnip',
    'watermelon'
]

def load_cnn_model():
    """Load the TFLite CNN model"""
    global cnn_model
    try:
        model_path = os.path.join(os.path.dirname(__file__), '..', 'models', 'fruit_vegetable_classifier.tflite')
        if os.path.exists(model_path):
            # Load TFLite model
            interpreter = tf.lite.Interpreter(model_path=model_path)
            interpreter.allocate_tensors()
            cnn_model = interpreter
            print(f"✅ CNN Model loaded from {model_path}")
        else:
            print(f"⚠️ CNN Model not found at {model_path}")
    except Exception as e:
        print(f"❌ Error loading CNN model: {e}")

# Load model on startup
load_cnn_model()

class QuestionRequest(BaseModel):
    session_id: str
    question: str

class ChatResponse(BaseModel):
    answer: str
    sources: Optional[List[str]] = None

class SessionConfig(BaseModel):
    session_id: str
    model: str = "Hugging Face"
    max_tokens: int = 512
    temperature: float = 0.7

class ImageClassifyRequest(BaseModel):
    image: str  # Base64 encoded image

class ClassificationResponse(BaseModel):
    predictions: dict  # {label: confidence}

@app.get("/")
async def root():
    return {"message": "RAG Chatbot API is running"}

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "cnn_model_loaded": cnn_model is not None,
        "lstm_model_trained": stock_service.is_trained
    }

@app.post("/classify", response_model=ClassificationResponse)
async def classify_image(request: ImageClassifyRequest):
    """Classify an image using the CNN model"""
    try:
        if cnn_model is None:
            raise HTTPException(
                status_code=503,
                detail="CNN model not loaded. Check if fruit_vegetable_classifier.tflite exists in models/ folder"
            )
        
        # Decode base64 image
        image_data = base64.b64decode(request.image)
        image = Image.open(io.BytesIO(image_data))
        
        print(f"📸 Image received: size={image.size}, mode={image.mode}")
        
        # Convert to RGB if necessary
        if image.mode != 'RGB':
            image = image.convert('RGB')
            print(f"  → Converted to RGB")
        
        # Resize to model input size (typically 224x224)
        image = image.resize((224, 224))
        print(f"  → Resized to 224x224")
        
        # Convert to numpy array and normalize
        img_array = np.array(image, dtype=np.float32)
        print(f"  → Array shape: {img_array.shape}, range: [{img_array.min():.1f}, {img_array.max():.1f}]")
        
        # IMPORTANT: Use same preprocessing as in Colab training
        # Try Method 2: Normalize to -1 to 1 (better performance in tests)
        img_array = (img_array / 127.5) - 1.0  # Normalize to -1 to 1
        print(f"  → Normalized range: [{img_array.min():.3f}, {img_array.max():.3f}]")
        
        img_array = np.expand_dims(img_array, axis=0)  # Add batch dimension
        print(f"  → Final shape: {img_array.shape}")
        
        # Get input and output details
        input_details = cnn_model.get_input_details()
        output_details = cnn_model.get_output_details()
        
        # Set input tensor
        cnn_model.set_tensor(input_details[0]['index'], img_array)
        
        # Run inference
        cnn_model.invoke()
        
        # Get output tensor
        output_data = cnn_model.get_tensor(output_details[0]['index'])
        predictions = output_data[0]
        
        print(f"🤖 Predictions: sum={predictions.sum():.3f}, max={predictions.max():.3f}")
        
        # Create result dictionary
        results = {}
        for i, label in enumerate(class_labels):
            if i < len(predictions):
                results[label] = float(predictions[i])
        
        # Sort by confidence
        results = dict(sorted(results.items(), key=lambda x: x[1], reverse=True))
        
        # Log top 3 predictions
        top_3 = list(results.items())[:3]
        print(f"🏆 Top 3: {', '.join([f'{k}={v*100:.1f}%' for k, v in top_3])}")
        
        return ClassificationResponse(predictions=results)
        
    except Exception as e:
        import traceback
        error_detail = f"{str(e)}\n\nTraceback:\n{traceback.format_exc()}"
        print(f"❌ Error classifying image: {error_detail}")
        raise HTTPException(status_code=500, detail=error_detail)

@app.post("/upload-pdf")
async def upload_pdf(
    files: List[UploadFile] = File(...),
    session_id: str = Form(...),
    model: str = Form("Hugging Face"),
    max_tokens: int = Form(512),
    temperature: float = Form(0.7)
):
    """Upload PDF files and create vector store"""
    try:
        # Extract text from all PDFs
        pdf_content = ""
        for file in files:
            # Save uploaded file temporarily
            with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp_file:
                content = await file.read()
                tmp_file.write(content)
                tmp_path = tmp_file.name
            
            # Read PDF
            pdf_reader = PdfReader(tmp_path)
            for page in pdf_reader.pages:
                pdf_content += page.extract_text()
            
            # Clean up temp file
            os.unlink(tmp_path)
        
        if not pdf_content.strip():
            raise HTTPException(status_code=400, detail="No text content found in PDFs")
        
        # Split text into chunks
        text_splitter = CharacterTextSplitter(
            separator="\n",
            chunk_size=1000,
            chunk_overlap=200,
            length_function=len,
        )
        chunks = text_splitter.split_text(pdf_content)
        
        # Create embeddings and vector store
        embeddings = HuggingFaceEmbeddings(
            model_name="sentence-transformers/all-mpnet-base-v2"
        )
        vector_store = FAISS.from_texts(
            texts=chunks,
            embedding=embeddings
        )
        
        # Use LLaMA-2 via Ollama
        llm = ChatOllama(
            model="llama3.2",
            temperature=temperature,
            num_predict=max_tokens,
        )
        
        # Create prompt template
        prompt = ChatPromptTemplate.from_template("""
        Answer the following question based only on the provided context:
        
        <context>
        {context}
        </context>
        
        Question: {question}
        """)
        
        # Create retrieval chain using LCEL
        retriever = vector_store.as_retriever()
        
        def format_docs(docs):
            return "\n\n".join(doc.page_content for doc in docs)
        
        # Build the chain
        rag_chain = (
            {"context": retriever | format_docs, "question": RunnablePassthrough()}
            | prompt
            | llm
            | StrOutputParser()
        )
        
        # Store in session
        sessions[session_id] = {
            "rag_chain": rag_chain,
            "retriever": retriever,
            "vector_store": vector_store,
            "model": model
        }
        
        return {
            "message": "PDFs processed successfully",
            "session_id": session_id,
            "chunks_count": len(chunks)
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ask", response_model=ChatResponse)
async def ask_question(request: QuestionRequest):
    """Ask a question using the RAG system"""
    try:
        print(f"📝 Received question: {request.question}")
        
        if request.session_id not in sessions:
            raise HTTPException(
                status_code=404,
                detail="Session not found. Please upload PDF files first."
            )
        
        print(f"✅ Session found: {request.session_id}")
        rag_chain = sessions[request.session_id]["rag_chain"]
        retriever = sessions[request.session_id]["retriever"]
        
        # Get response
        print("🤖 Generating answer...")
        answer = rag_chain.invoke(request.question)
        print(f"✅ Answer generated: {answer[:100]}...")
        
        # Get relevant documents for sources
        docs = retriever.invoke(request.question)
        
        return ChatResponse(
            answer=answer,
            sources=[doc.page_content[:200] for doc in docs[:3]]  # Top 3 sources
        )
    
    except Exception as e:
        import traceback
        error_detail = f"{str(e)}\n\nTraceback:\n{traceback.format_exc()}"
        print(f"❌ Error asking question: {error_detail}")
        raise HTTPException(status_code=500, detail=error_detail)

@app.delete("/session/{session_id}")
async def delete_session(session_id: str):
    """Delete a session and free up resources"""
    if session_id in sessions:
        del sessions[session_id]
        return {"message": "Session deleted successfully"}
    raise HTTPException(status_code=404, detail="Session not found")

@app.get("/sessions")
async def list_sessions():
    """List all active sessions"""
    return {
        "sessions": [
            {"session_id": sid, "model": info["model"]}
            for sid, info in sessions.items()
        ]
    }

@app.post("/train_stock_model")
async def train_stock_model(stock_symbol: str = 'TATA'):
    """Train LSTM model for stock price prediction"""
    try:
        print(f"🎓 Training LSTM model for {stock_symbol}")
        result = stock_service.train_model(stock_symbol=stock_symbol)
        return result
    except Exception as e:
        print(f"❌ Training error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict_stock")
async def predict_stock(stock_symbol: str = 'TATA', train: bool = False):
    """Predict stock prices using trained LSTM model"""
    try:
        print(f"📈 Predicting stock prices for {stock_symbol}")
        
        # Train if requested and not already trained
        if train and not stock_service.is_trained:
            print("  → Training model first...")
            train_result = stock_service.train_model(stock_symbol=stock_symbol)
            if train_result['status'] != 'success':
                return train_result
        
        result = stock_service.predict(stock_symbol=stock_symbol)
        return result
    except Exception as e:
        print(f"❌ Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
