"""
LSTM Stock Price Prediction Service
Trains and predicts stock prices using LSTM model
"""
from keras.models import Sequential
from keras.layers import LSTM, Dropout, Dense
from sklearn.preprocessing import MinMaxScaler
import numpy as np
import pandas as pd
import io
import base64
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Non-GUI backend

class StockPredictionService:
    def __init__(self):
        self.model = None
        self.scaler = MinMaxScaler(feature_range=(0, 1))
        self.is_trained = False
    
    def train_model(self, stock_symbol='TATA'):
        """Train LSTM model with stock data"""
        try:
            # Load training data
            if stock_symbol == 'TATA':
                url = 'https://raw.githubusercontent.com/mwitiderrick/stockprice/master/NSE-TATAGLOBAL.csv'
            else:
                url = 'https://raw.githubusercontent.com/mwitiderrick/stockprice/master/NSE-TATAGLOBAL.csv'
            
            dataset_train = pd.read_csv(url)
            training_set = dataset_train.iloc[:, 1:2].values
            
            # Scale the training set
            training_set_scaled = self.scaler.fit_transform(training_set)
            
            # Prepare training data
            X_train = []
            y_train = []
            for i in range(60, len(training_set_scaled)):
                X_train.append(training_set_scaled[i-60:i, 0])
                y_train.append(training_set_scaled[i, 0])
            
            X_train, y_train = np.array(X_train), np.array(y_train)
            X_train = np.reshape(X_train, (X_train.shape[0], X_train.shape[1], 1))
            
            # Build LSTM model
            self.model = Sequential()
            self.model.add(LSTM(units=50, return_sequences=True, input_shape=(X_train.shape[1], 1)))
            self.model.add(Dropout(0.2))
            self.model.add(LSTM(units=50, return_sequences=True))
            self.model.add(Dropout(0.2))
            self.model.add(LSTM(units=50, return_sequences=True))
            self.model.add(Dropout(0.2))
            self.model.add(LSTM(units=50))
            self.model.add(Dropout(0.2))
            self.model.add(Dense(units=1))
            
            self.model.compile(optimizer='adam', loss='mean_squared_error')
            
            # Train model
            history = self.model.fit(X_train, y_train, epochs=5, batch_size=32, verbose=0)
            
            self.is_trained = True
            return {
                'status': 'success',
                'message': 'Model trained successfully',
                'final_loss': float(history.history['loss'][-1])
            }
        
        except Exception as e:
            return {
                'status': 'error',
                'message': str(e)
            }
    
    def predict(self, stock_symbol='TATA', days_ahead=10):
        """Make predictions using trained model"""
        try:
            if not self.is_trained:
                return {
                    'status': 'error',
                    'message': 'Model not trained. Please train the model first.'
                }
            
            # Load test data
            if stock_symbol == 'TATA':
                train_url = 'https://raw.githubusercontent.com/mwitiderrick/stockprice/master/NSE-TATAGLOBAL.csv'
                test_url = 'https://raw.githubusercontent.com/mwitiderrick/stockprice/master/tatatest.csv'
            else:
                train_url = 'https://raw.githubusercontent.com/mwitiderrick/stockprice/master/NSE-TATAGLOBAL.csv'
                test_url = 'https://raw.githubusercontent.com/mwitiderrick/stockprice/master/tatatest.csv'
            
            dataset_train = pd.read_csv(train_url)
            dataset_test = pd.read_csv(test_url)
            real_stock_price = dataset_test.iloc[:, 1:2].values
            
            # Prepare test data
            dataset_total = pd.concat((dataset_train['Open'], dataset_test['Open']), axis=0)
            inputs = dataset_total[len(dataset_total) - len(dataset_test) - 60:].values
            inputs = inputs.reshape(-1, 1)
            inputs = self.scaler.transform(inputs)
            
            X_test = []
            for i in range(60, 60 + len(dataset_test)):
                X_test.append(inputs[i-60:i, 0])
            
            X_test = np.array(X_test)
            X_test = np.reshape(X_test, (X_test.shape[0], X_test.shape[1], 1))
            
            # Make predictions
            predicted_stock_price = self.model.predict(X_test, verbose=0)
            predicted_stock_price = self.scaler.inverse_transform(predicted_stock_price)
            
            # Generate plot
            plt.figure(figsize=(10, 6))
            plt.plot(real_stock_price, color='black', label=f'{stock_symbol} Stock Price', linewidth=2)
            plt.plot(predicted_stock_price, color='green', label=f'Predicted {stock_symbol} Stock Price', linewidth=2)
            plt.title(f'{stock_symbol} Stock Price Prediction', fontsize=16, fontweight='bold')
            plt.xlabel('Time', fontsize=12)
            plt.ylabel(f'{stock_symbol} Stock Price', fontsize=12)
            plt.legend()
            plt.grid(True, alpha=0.3)
            plt.tight_layout()
            
            # Convert plot to base64
            buffer = io.BytesIO()
            plt.savefig(buffer, format='png', dpi=100, bbox_inches='tight')
            buffer.seek(0)
            image_base64 = base64.b64encode(buffer.read()).decode()
            plt.close()
            
            # Calculate metrics
            mse = np.mean((real_stock_price - predicted_stock_price) ** 2)
            mae = np.mean(np.abs(real_stock_price - predicted_stock_price))
            
            return {
                'status': 'success',
                'predictions': predicted_stock_price.flatten().tolist(),
                'actual': real_stock_price.flatten().tolist(),
                'plot': image_base64,
                'metrics': {
                    'mse': float(mse),
                    'mae': float(mae)
                }
            }
        
        except Exception as e:
            import traceback
            return {
                'status': 'error',
                'message': str(e),
                'traceback': traceback.format_exc()
            }

# Global instance
stock_service = StockPredictionService()
